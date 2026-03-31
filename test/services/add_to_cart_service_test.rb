require "test_helper"

class AddToCartServiceTest < ActiveSupport::TestCase
  def setup
    @cart = Cart.create!(session_token: SecureRandom.uuid)
    @product = Product.create!(name: "Test Product", price: 10.00, stock_quantity: 10)
  end

  # Successful add to cart
  test "successfully adds product to empty cart" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 3)

    assert service.success?, "Service should succeed"
    assert_equal 1, @cart.cart_items.count
    assert_equal 3, @cart.cart_items.first.quantity
    assert_equal @product, @cart.cart_items.first.product
  end

  test "creates cart_item with active reservation" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 2)

    assert service.success?
    cart_item = @cart.cart_items.first
    assert cart_item.reserved_until > Time.current
    assert_not cart_item.reservation_expired?
  end

  test "adds to existing cart_item when product already in cart" do
    # Add product first time
    @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)

    # Add same product again
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 3)

    assert service.success?
    assert_equal 1, @cart.cart_items.count, "Should still have only one cart_item"
    assert_equal 5, @cart.cart_items.first.quantity, "Quantity should be 2 + 3 = 5"
  end

  test "extends reservation when adding to existing cart_item" do
    # Create cart_item with reservation expiring soon
    cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 5.minutes.from_now)
    original_reservation = cart_item.reserved_until

    # Add more quantity
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 1)

    assert service.success?
    cart_item.reload
    assert cart_item.reserved_until > original_reservation, "Reservation should be extended"
    assert cart_item.reserved_until > Time.current + 25.minutes
  end

  # Stock validation
  test "fails when quantity exceeds available stock" do
    @product.update!(stock_quantity: 5)

    service = AddToCartService.call(cart: @cart, product: @product, quantity: 10)

    assert_not service.success?, "Should fail when quantity exceeds stock"
    assert_includes service.error_message, "Only 5 available"
    assert_equal 0, @cart.cart_items.count, "Should not create cart_item"
  end

  test "respects existing reservations when checking stock" do
    # Another cart reserves 7 units
    other_cart = Cart.create!(session_token: SecureRandom.uuid)
    other_cart.cart_items.create!(product: @product, quantity: 7, reserved_until: 30.minutes.from_now)

    # @product has 10 in stock, 7 reserved, so only 3 available
    assert_equal 3, @product.available_quantity

    # Try to add 5 (more than available)
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 5)

    assert_not service.success?
    assert_includes service.error_message, "Only 3 available"
  end

  test "succeeds when quantity equals available stock" do
    @product.update!(stock_quantity: 5)

    service = AddToCartService.call(cart: @cart, product: @product, quantity: 5)

    assert service.success?, "Should succeed when quantity equals available stock"
    assert_equal 5, @cart.cart_items.first.quantity
  end

  test "considers current cart's reservation when adding more" do
    # Cart already has 3 reserved
    @cart.cart_items.create!(product: @product, quantity: 3, reserved_until: 30.minutes.from_now)

    # Product has 10 in stock, 3 reserved by this cart, so 7 available
    # But when we add to existing cart_item, we're adding on top of our own reservation
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 7)

    # This should succeed because we're updating our own reservation from 3 to 10
    assert service.success?
    @cart.cart_items.first.reload
    assert_equal 10, @cart.cart_items.first.quantity
  end

  # Quantity validation
  test "fails when quantity is zero" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 0)

    assert_not service.success?
    assert_includes service.error_message, "Quantity must be greater than 0"
    assert_equal 0, @cart.cart_items.count
  end

  test "fails when quantity is negative" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: -5)

    assert_not service.success?
    assert_includes service.error_message, "Quantity must be greater than 0"
    assert_equal 0, @cart.cart_items.count
  end

  test "accepts quantity as string" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: "3")

    assert service.success?, "Should convert string to integer"
    assert_equal 3, @cart.cart_items.first.quantity
  end

  # Out of stock scenarios
  test "fails when product is out of stock" do
    @product.update!(stock_quantity: 0)

    service = AddToCartService.call(cart: @cart, product: @product, quantity: 1)

    assert_not service.success?
    assert_includes service.error_message, "Only 0 available"
  end

  test "fails when all stock is reserved by other carts" do
    @product.update!(stock_quantity: 5)

    # Other carts reserve all stock
    cart1 = Cart.create!(session_token: SecureRandom.uuid)
    cart2 = Cart.create!(session_token: SecureRandom.uuid)
    cart1.cart_items.create!(product: @product, quantity: 3, reserved_until: 30.minutes.from_now)
    cart2.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)

    # Now available_quantity is 0
    assert_equal 0, @product.available_quantity

    service = AddToCartService.call(cart: @cart, product: @product, quantity: 1)

    assert_not service.success?
    assert_includes service.error_message, "Only 0 available"
  end

  # Transaction rollback
  test "does not create cart_item if validation fails" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 0)

    assert_not service.success?
    assert_equal 0, @cart.cart_items.count, "Should not create cart_item on validation failure"
  end

  # Service interface
  test "returns self to allow chaining" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 2)
    assert_instance_of AddToCartService, service
  end

  test "success? returns true on success" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 2)
    assert service.success?
  end

  test "success? returns false on failure" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 0)
    assert_not service.success?
  end

  test "error_message returns string" do
    service = AddToCartService.call(cart: @cart, product: @product, quantity: 0)
    assert_instance_of String, service.error_message
    assert service.error_message.length > 0
  end
end
