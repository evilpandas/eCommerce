require "test_helper"

class MergeCartsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @user_cart = Cart.create!(user: @user, session_token: SecureRandom.uuid)
    @guest_cart = Cart.create!(session_token: SecureRandom.uuid)
    @product1 = Product.create!(name: "Product 1", price: 10.00, stock_quantity: 20)
    @product2 = Product.create!(name: "Product 2", price: 20.00, stock_quantity: 15)
    @product3 = Product.create!(name: "Product 3", price: 30.00, stock_quantity: 10)
  end

  # Basic merge scenarios
  test "merges guest cart into empty user cart" do
    @guest_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)
    @guest_cart.cart_items.create!(product: @product2, quantity: 1, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    @user_cart.reload
    assert_equal 2, @user_cart.cart_items.count
    assert_nil Cart.find_by(id: @guest_cart.id), "Guest cart should be destroyed"
  end

  test "transfers all guest cart items to user cart" do
    @guest_cart.cart_items.create!(product: @product1, quantity: 3, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    user_item = @user_cart.cart_items.find_by(product: @product1)
    assert_not_nil user_item
    assert_equal 3, user_item.quantity
  end

  test "extends reservation when merging guest item" do
    guest_item = @guest_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 5.minutes.from_now)
    original_reservation = guest_item.reserved_until

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    merged_item = @user_cart.cart_items.find_by(product: @product1)
    assert merged_item.reserved_until > original_reservation
    assert merged_item.reserved_until > Time.current + 25.minutes
  end

  # Duplicate product handling
  test "combines quantities when both carts have same product" do
    # User cart already has 2 of product1
    @user_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)

    # Guest cart has 3 of product1
    @guest_cart.cart_items.create!(product: @product1, quantity: 3, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    assert_equal 1, @user_cart.cart_items.count, "Should have only one cart_item for product1"

    user_item = @user_cart.cart_items.find_by(product: @product1)
    assert_equal 5, user_item.quantity, "Should combine 2 + 3 = 5"
  end

  test "extends reservation when combining duplicate products" do
    user_item = @user_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 5.minutes.from_now)
    @guest_cart.cart_items.create!(product: @product1, quantity: 3, reserved_until: 30.minutes.from_now)

    original_reservation = user_item.reserved_until

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    user_item.reload
    assert user_item.reserved_until > original_reservation
    assert user_item.reserved_until > Time.current + 25.minutes
  end

  test "handles multiple overlapping products" do
    # User cart has product1 and product2
    @user_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)
    @user_cart.cart_items.create!(product: @product2, quantity: 1, reserved_until: 30.minutes.from_now)

    # Guest cart has product2 (overlap) and product3 (new)
    @guest_cart.cart_items.create!(product: @product2, quantity: 2, reserved_until: 30.minutes.from_now)
    @guest_cart.cart_items.create!(product: @product3, quantity: 1, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    assert_equal 3, @user_cart.cart_items.count

    product1_item = @user_cart.cart_items.find_by(product: @product1)
    product2_item = @user_cart.cart_items.find_by(product: @product2)
    product3_item = @user_cart.cart_items.find_by(product: @product3)

    assert_equal 2, product1_item.quantity, "Product1 unchanged"
    assert_equal 3, product2_item.quantity, "Product2 combined: 1 + 2 = 3"
    assert_equal 1, product3_item.quantity, "Product3 added"
  end

  # Empty cart scenarios
  test "handles empty guest cart" do
    # User cart has items
    @user_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    assert_equal 1, @user_cart.cart_items.count
    assert_nil Cart.find_by(id: @guest_cart.id), "Guest cart should still be destroyed"
  end

  test "handles nil guest cart" do
    # User cart has items
    @user_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: nil)

    assert service.success?, "Should succeed gracefully with nil guest cart"
    assert_equal 1, @user_cart.cart_items.count, "User cart should be unchanged"
  end

  test "merges into empty user cart" do
    @guest_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)
    @guest_cart.cart_items.create!(product: @product2, quantity: 3, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    assert_equal 2, @user_cart.cart_items.count
  end

  # Transaction behavior
  test "destroys guest cart after successful merge" do
    @guest_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)

    guest_cart_id = @guest_cart.id
    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    assert_nil Cart.find_by(id: guest_cart_id), "Guest cart should be destroyed"
  end

  test "all guest cart items belong to user cart after merge" do
    @guest_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)
    @guest_cart.cart_items.create!(product: @product2, quantity: 1, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    @user_cart.cart_items.each do |item|
      assert_equal @user_cart.id, item.cart_id
    end
  end

  # Complex scenarios
  test "handles many items in guest cart" do
    products = 5.times.map do |i|
      Product.create!(name: "Product #{i}", price: 10.00 + i, stock_quantity: 10)
    end

    products.each do |product|
      @guest_cart.cart_items.create!(product: product, quantity: 1, reserved_until: 30.minutes.from_now)
    end

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    assert_equal 5, @user_cart.cart_items.count
  end

  test "preserves product associations after merge" do
    @guest_cart.cart_items.create!(product: @product1, quantity: 2, reserved_until: 30.minutes.from_now)

    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)

    assert service.success?
    user_item = @user_cart.cart_items.first
    assert_equal @product1.id, user_item.product_id
    assert_equal @product1, user_item.product
  end

  # Service interface
  test "returns self" do
    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)
    assert_instance_of MergeCartsService, service
  end

  test "success? always returns true" do
    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: @guest_cart)
    assert service.success?
  end

  test "succeeds even with nil guest cart" do
    service = MergeCartsService.call(user_cart: @user_cart, guest_cart: nil)
    assert service.success?
  end
end
