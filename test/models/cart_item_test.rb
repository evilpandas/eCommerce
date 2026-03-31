require "test_helper"

class CartItemTest < ActiveSupport::TestCase
  def setup
    @cart = Cart.create!(session_token: SecureRandom.uuid)
    @product = Product.create!(name: "Test Product", price: 15.00, stock_quantity: 10)
  end

  # Association tests
  test "belongs to cart" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)
    assert_equal @cart, cart_item.cart
  end

  test "belongs to product" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)
    assert_equal @product, cart_item.product
  end

  # Validation tests
  test "validates quantity is greater than 0" do
    cart_item = @cart.cart_items.build(product: @product, quantity: 0, reserved_until: 30.minutes.from_now)
    assert_not cart_item.save, "Saved cart_item with quantity 0"
  end

  test "validates quantity is not negative" do
    cart_item = @cart.cart_items.build(product: @product, quantity: -1, reserved_until: 30.minutes.from_now)
    assert_not cart_item.save, "Saved cart_item with negative quantity"
  end

  test "saves cart_item with valid quantity" do
    cart_item = @cart.cart_items.build(product: @product, quantity: 3, reserved_until: 30.minutes.from_now)
    assert cart_item.save, "Failed to save cart_item with valid quantity"
  end

  # Reservation lifecycle tests
  test "sets reservation_expiry before create when not explicitly set" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2)
    assert_not_nil cart_item.reserved_until
    assert cart_item.reserved_until > Time.current
    assert cart_item.reserved_until <= (Time.current + CartItem::RESERVATION_DURATION + 1.second)
  end

  test "does not override explicitly set reserved_until" do
    explicit_time = 1.hour.from_now
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: explicit_time)
    assert_in_delta explicit_time.to_i, cart_item.reserved_until.to_i, 1
  end

  # reservation_expired? method
  test "reservation_expired? returns true when reserved_until is in the past" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 1.hour.ago)
    assert cart_item.reservation_expired?, "Should detect expired reservation"
  end

  test "reservation_expired? returns false when reserved_until is in the future" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)
    assert_not cart_item.reservation_expired?, "Should not be expired"
  end

  test "reservation_expired? returns true when reserved_until is exactly now" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: Time.current)
    assert cart_item.reservation_expired?, "Should be expired when exactly at Time.current"
  end

  # extend_reservation! method
  test "extend_reservation! updates reserved_until to 30 minutes from now" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 5.minutes.from_now)
    original_time = cart_item.reserved_until

    cart_item.extend_reservation!
    cart_item.reload

    assert cart_item.reserved_until > original_time
    assert cart_item.reserved_until > Time.current + 25.minutes
    assert cart_item.reserved_until <= Time.current + 31.minutes
  end

  test "extend_reservation! can revive expired reservation" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 1.hour.ago)
    assert cart_item.reservation_expired?

    cart_item.extend_reservation!
    cart_item.reload

    assert_not cart_item.reservation_expired?, "Reservation should be active after extension"
    assert cart_item.reserved_until > Time.current
  end

  # Scopes
  test "active_reservations scope includes future reservations" do
    active_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)
    expired_item = @cart.cart_items.create!(
      product: Product.create!(name: "Product 2", price: 10.00, stock_quantity: 5),
      quantity: 1,
      reserved_until: 1.hour.ago
    )

    active_items = CartItem.active_reservations
    assert_includes active_items, active_item
    assert_not_includes active_items, expired_item
  end

  test "expired_reservations scope includes past reservations" do
    active_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)
    expired_item = @cart.cart_items.create!(
      product: Product.create!(name: "Product 2", price: 10.00, stock_quantity: 5),
      quantity: 1,
      reserved_until: 1.hour.ago
    )

    expired_items = CartItem.expired_reservations
    assert_includes expired_items, expired_item
    assert_not_includes expired_items, active_item
  end

  test "active_reservations scope excludes items at exactly Time.current" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: Time.current)
    active_items = CartItem.active_reservations
    assert_not_includes active_items, cart_item
  end

  # subtotal method
  test "subtotal calculates price * quantity" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 3, reserved_until: 30.minutes.from_now)
    assert_equal 45.00, cart_item.subtotal # 15.00 * 3
  end

  test "subtotal handles quantity of 1" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 1, reserved_until: 30.minutes.from_now)
    assert_equal 15.00, cart_item.subtotal
  end

  test "subtotal updates when quantity changes" do
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)
    assert_equal 30.00, cart_item.subtotal

    cart_item.update!(quantity: 5)
    assert_equal 75.00, cart_item.subtotal
  end

  # Unique constraint test (cart_id + product_id must be unique)
  test "cannot create duplicate cart_items for same cart and product" do
    @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)

    assert_raises ActiveRecord::RecordNotUnique do
      @cart.cart_items.create!(product: @product, quantity: 1, reserved_until: 30.minutes.from_now)
    end
  end

  test "can create cart_items for same product in different carts" do
    cart2 = Cart.create!(session_token: SecureRandom.uuid)

    item1 = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)
    item2 = cart2.cart_items.create!(product: @product, quantity: 3, reserved_until: 30.minutes.from_now)

    assert item1.persisted?
    assert item2.persisted?
    assert_not_equal item1.cart_id, item2.cart_id
  end
end
