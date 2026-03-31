require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def setup
    @product = products(:one)
  end

  # Validation tests
  test "should not save product without name" do
    product = Product.new(price: 10.00, stock_quantity: 5)
    assert_not product.save, "Saved product without name"
  end

  test "should not save product without price" do
    product = Product.new(name: "Test Product", stock_quantity: 5)
    assert_not product.save, "Saved product without price"
  end

  test "should not save product with negative price" do
    product = Product.new(name: "Test Product", price: -5.00, stock_quantity: 5)
    assert_not product.save, "Saved product with negative price"
  end

  test "should not save product with negative stock_quantity" do
    product = Product.new(name: "Test Product", price: 10.00, stock_quantity: -1)
    assert_not product.save, "Saved product with negative stock quantity"
  end

  test "should not save product with non-integer stock_quantity" do
    product = Product.new(name: "Test Product", price: 10.00, stock_quantity: 5.5)
    assert_not product.save, "Saved product with decimal stock quantity"
  end

  # in_stock? and out_of_stock? tests
  test "in_stock? returns true when stock_quantity is greater than zero" do
    @product.update(stock_quantity: 5)
    assert @product.in_stock?, "Product should be in stock"
  end

  test "in_stock? returns false when stock_quantity is zero" do
    @product.update(stock_quantity: 0)
    assert_not @product.in_stock?, "Product should not be in stock"
  end

  test "out_of_stock? returns true when stock_quantity is zero" do
    @product.update(stock_quantity: 0)
    assert @product.out_of_stock?, "Product should be out of stock"
  end

  test "out_of_stock? returns false when stock_quantity is greater than zero" do
    @product.update(stock_quantity: 5)
    assert_not @product.out_of_stock?, "Product should not be out of stock"
  end

  # Inventory reservation tests (CRITICAL)
  test "reserved_quantity calculates total quantity in active cart items" do
    # Use a fresh product without fixture cart_items
    product = Product.create!(name: "Test Product", price: 10.00, stock_quantity: 10)

    # Create different carts with active items (can't have multiple items for same product in one cart)
    cart1 = Cart.create!(session_token: SecureRandom.uuid)
    cart2 = Cart.create!(session_token: SecureRandom.uuid)
    cart1.cart_items.create!(product: product, quantity: 3, reserved_until: 30.minutes.from_now)
    cart2.cart_items.create!(product: product, quantity: 2, reserved_until: 15.minutes.from_now)

    assert_equal 5, product.reserved_quantity, "Should calculate 3 + 2 = 5 reserved"
  end

  test "reserved_quantity ignores expired reservations" do
    # Use a fresh product without fixture cart_items
    product = Product.create!(name: "Test Product", price: 10.00, stock_quantity: 10)

    cart1 = Cart.create!(session_token: SecureRandom.uuid)
    cart2 = Cart.create!(session_token: SecureRandom.uuid)
    cart1.cart_items.create!(product: product, quantity: 3, reserved_until: 1.hour.ago) # Expired
    cart2.cart_items.create!(product: product, quantity: 2, reserved_until: 30.minutes.from_now) # Active

    assert_equal 2, product.reserved_quantity, "Should only count active reservations"
  end

  test "available_quantity subtracts reserved from stock" do
    # Use a fresh product without fixture cart_items
    product = Product.create!(name: "Test Product", price: 10.00, stock_quantity: 10)

    cart = Cart.create!(session_token: SecureRandom.uuid)
    cart.cart_items.create!(product: product, quantity: 3, reserved_until: 30.minutes.from_now)

    assert_equal 7, product.available_quantity, "Should be 10 - 3 = 7 available"
  end

  test "available_quantity returns zero when all stock is reserved" do
    # Use a fresh product without fixture cart_items
    product = Product.create!(name: "Test Product", price: 10.00, stock_quantity: 10)

    cart = Cart.create!(session_token: SecureRandom.uuid)
    cart.cart_items.create!(product: product, quantity: 10, reserved_until: 30.minutes.from_now)

    assert_equal 0, product.available_quantity, "Should be zero when fully reserved"
  end

  test "available_quantity handles multiple carts reserving same product" do
    # Use a fresh product without fixture cart_items
    product = Product.create!(name: "Test Product", price: 10.00, stock_quantity: 20)

    cart1 = Cart.create!(session_token: SecureRandom.uuid)
    cart2 = Cart.create!(session_token: SecureRandom.uuid)
    cart3 = Cart.create!(session_token: SecureRandom.uuid)

    cart1.cart_items.create!(product: product, quantity: 5, reserved_until: 30.minutes.from_now)
    cart2.cart_items.create!(product: product, quantity: 3, reserved_until: 25.minutes.from_now)
    cart3.cart_items.create!(product: product, quantity: 2, reserved_until: 20.minutes.from_now)

    assert_equal 10, product.available_quantity, "Should be 20 - (5+3+2) = 10 available"
  end
end
