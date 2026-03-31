class AddToCartService < ApplicationService
  attr_reader :cart, :product, :quantity, :errors

  def initialize(cart:, product:, quantity:)
    @cart = cart
    @product = product
    @quantity = quantity.to_i
    @errors = []
  end

  def call
    validate!
    return self unless errors.empty?

    ActiveRecord::Base.transaction do
      cart_item = find_or_initialize_cart_item

      if cart_item.persisted?
        # Update existing item
        cart_item.quantity += quantity
        cart_item.extend_reservation!
      else
        # Create new item (reservation set by before_create callback)
        cart_item.quantity = quantity
      end

      cart_item.save!
    end

    self
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.message
    self
  end

  def success?
    errors.empty?
  end

  def error_message
    errors.join(", ")
  end

  private

  def validate!
    if quantity <= 0
      @errors << "Quantity must be greater than 0"
    end

    if product.available_quantity < quantity
      @errors << "Only #{product.available_quantity} available"
    end
  end

  def find_or_initialize_cart_item
    cart.cart_items.find_or_initialize_by(product: product)
  end
end
