require "test_helper"

class UpdateCartItemServiceTest < ActiveSupport::TestCase
  def setup
    @cart = Cart.create!(session_token: SecureRandom.uuid)
    @product = Product.create!(name: "Test Product", price: 10.00, stock_quantity: 10)
    @cart_item = @cart.cart_items.create!(product: @product, quantity: 2, reserved_until: 30.minutes.from_now)
  end

  # Successful updates
  test "successfully updates cart_item quantity" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 5)

    assert service.success?, "Service should succeed"
    @cart_item.reload
    assert_equal 5, @cart_item.quantity
  end

  test "extends reservation when updating quantity" do
    # Create cart_item with reservation expiring soon
    @cart_item.update_column(:reserved_until, 5.minutes.from_now)
    original_reservation = @cart_item.reserved_until

    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 3)

    assert service.success?
    @cart_item.reload
    assert @cart_item.reserved_until > original_reservation, "Reservation should be extended"
    assert @cart_item.reserved_until > Time.current + 25.minutes
  end

  test "can decrease quantity" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 1)

    assert service.success?
    @cart_item.reload
    assert_equal 1, @cart_item.quantity
  end

  test "can increase quantity" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 5)

    assert service.success?
    @cart_item.reload
    assert_equal 5, @cart_item.quantity
  end

  test "accepts quantity as string" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: "7")

    assert service.success?, "Should convert string to integer"
    @cart_item.reload
    assert_equal 7, @cart_item.quantity
  end

  # Stock validation
  test "fails when new quantity exceeds available stock" do
    @product.update!(stock_quantity: 5)
    # cart_item has 2, so 3 available (5 - 2)
    # Trying to update to 6 should fail

    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 6)

    assert_not service.success?
    assert_includes service.error_message, "Only 5 available"
    @cart_item.reload
    assert_equal 2, @cart_item.quantity, "Quantity should not change on failure"
  end

  test "considers current cart_item reservation when checking stock" do
    # Product has 10 in stock, cart_item has 2 reserved
    # So available is 8, but max we can update to is 10 (8 + our current 2)
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 10)

    assert service.success?, "Should succeed when updating to total stock"
    @cart_item.reload
    assert_equal 10, @cart_item.quantity
  end

  test "respects other cart reservations when updating" do
    # Another cart reserves 5 units
    other_cart = Cart.create!(session_token: SecureRandom.uuid)
    other_cart.cart_items.create!(product: @product, quantity: 5, reserved_until: 30.minutes.from_now)

    # Product has 10 in stock, 5 reserved by other cart, 2 reserved by our cart
    # reserved_quantity = 5 + 2 = 7
    # available_quantity = 10 - 7 = 3
    # max we can update to = available_quantity + our current quantity = 3 + 2 = 5
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 5)

    assert service.success?
    @cart_item.reload
    assert_equal 5, @cart_item.quantity
  end

  test "fails when trying to exceed stock considering other reservations" do
    # Another cart reserves 5 units
    other_cart = Cart.create!(session_token: SecureRandom.uuid)
    other_cart.cart_items.create!(product: @product, quantity: 5, reserved_until: 30.minutes.from_now)

    # Max we can update to is 5, trying 6 should fail
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 6)

    assert_not service.success?
    assert_includes service.error_message, "Only 5 available"
  end

  # Quantity validation
  test "fails when quantity is zero" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 0)

    assert_not service.success?
    assert_includes service.error_message, "Quantity must be greater than 0"
    @cart_item.reload
    assert_equal 2, @cart_item.quantity, "Quantity should not change"
  end

  test "fails when quantity is negative" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: -1)

    assert_not service.success?
    assert_includes service.error_message, "Quantity must be greater than 0"
    @cart_item.reload
    assert_equal 2, @cart_item.quantity
  end

  # Reservation expiration
  test "fails when reservation has expired" do
    @cart_item.update_column(:reserved_until, 1.hour.ago)

    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 3)

    assert_not service.success?
    assert_includes service.error_message, "Reservation expired"
  end

  test "succeeds when reservation is still active" do
    @cart_item.update_column(:reserved_until, 30.minutes.from_now)

    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 3)

    assert service.success?
  end

  # Edge cases
  test "succeeds when quantity equals total stock" do
    @product.update!(stock_quantity: 5)

    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 5)

    assert service.success?
    @cart_item.reload
    assert_equal 5, @cart_item.quantity
  end

  test "fails when product is out of stock and trying to increase" do
    # Set stock to match current reservation
    @product.update!(stock_quantity: 2)

    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 3)

    assert_not service.success?
    assert_includes service.error_message, "Only 2 available"
  end

  test "succeeds when decreasing quantity even if product out of stock" do
    # Product has 2 in stock (all reserved by this cart_item)
    @product.update!(stock_quantity: 2)

    # Decreasing from 2 to 1 should work
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 1)

    assert service.success?
    @cart_item.reload
    assert_equal 1, @cart_item.quantity
  end

  # Transaction rollback
  test "does not update cart_item if validation fails" do
    original_quantity = @cart_item.quantity

    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 0)

    assert_not service.success?
    @cart_item.reload
    assert_equal original_quantity, @cart_item.quantity, "Should not update on validation failure"
  end

  # Service interface
  test "returns self to allow chaining" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 3)
    assert_instance_of UpdateCartItemService, service
  end

  test "success? returns true on success" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 3)
    assert service.success?
  end

  test "success? returns false on failure" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 0)
    assert_not service.success?
  end

  test "error_message returns string" do
    service = UpdateCartItemService.call(cart_item: @cart_item, quantity: 0)
    assert_instance_of String, service.error_message
    assert service.error_message.length > 0
  end
end
