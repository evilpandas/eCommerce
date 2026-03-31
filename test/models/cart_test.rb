require "test_helper"

class CartTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @product1 = Product.create!(name: "Product 1", price: 10.00, stock_quantity: 5)
    @product2 = Product.create!(name: "Product 2", price: 20.00, stock_quantity: 3)
  end

  # Association tests
  test "belongs to user" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    assert_equal @user, cart.user
  end

  test "can be created without user (guest cart)" do
    cart = Cart.create!(session_token: SecureRandom.uuid)
    assert_nil cart.user
    assert cart.guest?
  end

  test "has many cart_items" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)
    cart.cart_items.create!(product: @product2, quantity: 1, reserved_until: 30.minutes.from_now)

    assert_equal 2, cart.cart_items.count
  end

  test "has many products through cart_items" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)
    cart.cart_items.create!(product: @product2, quantity: 1, reserved_until: 30.minutes.from_now)

    assert_includes cart.products, @product1
    assert_includes cart.products, @product2
    assert_equal 2, cart.products.count
  end

  test "generates session_token before create" do
    cart = Cart.create!(user: @user)
    assert_not_nil cart.session_token
    assert cart.session_token.is_a?(String)
  end

  # Scopes
  test "guest scope returns carts without user" do
    guest_cart = Cart.create!(session_token: SecureRandom.uuid)
    user_cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)

    guest_carts = Cart.guest
    assert_includes guest_carts, guest_cart
    assert_not_includes guest_carts, user_cart
  end

  test "authenticated scope returns carts with user" do
    guest_cart = Cart.create!(session_token: SecureRandom.uuid)
    user_cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)

    authenticated_carts = Cart.authenticated
    assert_includes authenticated_carts, user_cart
    assert_not_includes authenticated_carts, guest_cart
  end

  test "expired scope returns carts past expires_at" do
    expired_cart = Cart.create!(session_token: SecureRandom.uuid, expires_at: 1.day.ago)
    active_cart = Cart.create!(session_token: SecureRandom.uuid, expires_at: 1.day.from_now)

    expired_carts = Cart.expired
    assert_includes expired_carts, expired_cart
    assert_not_includes expired_carts, active_cart
  end

  # Calculations
  test "total_price sums all cart item subtotals" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now) # 2 * 10.00 = 20.00
    cart.cart_items.create!(product: @product2, quantity: 3, reserved_until: 30.minutes.from_now) # 3 * 20.00 = 60.00

    assert_equal 80.00, cart.total_price
  end

  test "total_price returns 0 for empty cart" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    assert_equal 0, cart.total_price
  end

  test "total_items sums all cart item quantities" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)
    cart.cart_items.create!(product: @product2, quantity: 3, reserved_until: 30.minutes.from_now)

    assert_equal 5, cart.total_items
  end

  test "total_items returns 0 for empty cart" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    assert_equal 0, cart.total_items
  end

  # guest? method
  test "guest? returns true when user_id is nil" do
    cart = Cart.create!(session_token: SecureRandom.uuid)
    assert cart.guest?
  end

  test "guest? returns false when user is present" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    assert_not cart.guest?
  end

  # Dependent destroy
  test "destroying cart destroys associated cart_items" do
    cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)
    cart.cart_items.create!(product: @product2, quantity: 1, reserved_until: 30.minutes.from_now)

    cart_item_ids = cart.cart_items.pluck(:id)
    cart.destroy

    cart_item_ids.each do |id|
      assert_nil CartItem.find_by(id: id), "CartItem #{id} should be destroyed"
    end
  end
end
