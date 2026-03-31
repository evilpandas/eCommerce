class UpdateCartItemService < ApplicationService
  attr_reader :cart_item, :quantity, :errors

  def initialize(cart_item:, quantity:)
    @cart_item = cart_item
    @quantity = quantity.to_i
    @errors = []
  end

  def call
    validate!
    return self unless errors.empty?

    ActiveRecord::Base.transaction do
      cart_item.quantity = quantity
      cart_item.extend_reservation!
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

    # Check available stock (current reservation + available inventory)
    max_available = cart_item.product.available_quantity + cart_item.quantity
    if quantity > max_available
      @errors << "Only #{max_available} available"
    end

    if cart_item.reservation_expired?
      @errors << "Reservation expired, please add item to cart again"
    end
  end
end
