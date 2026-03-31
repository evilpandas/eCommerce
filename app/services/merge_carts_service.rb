class MergeCartsService < ApplicationService
  attr_reader :user_cart, :guest_cart

  def initialize(user_cart:, guest_cart:)
    @user_cart = user_cart
    @guest_cart = guest_cart
  end

  def call
    return self if guest_cart.nil?

    ActiveRecord::Base.transaction do
      guest_cart.cart_items.to_a.each do |guest_item|
        merge_item(guest_item)
      end

      guest_cart.destroy
    end

    self
  end

  def success?
    true
  end

  private

  def merge_item(guest_item)
    existing_item = user_cart.cart_items.find_by(product_id: guest_item.product_id)

    if existing_item
      # Combine quantities and extend reservation
      existing_item.quantity += guest_item.quantity
      existing_item.extend_reservation!
      existing_item.save!
      guest_item.destroy
    else
      # Create new item in user cart
      user_cart.cart_items.create!(
        product_id: guest_item.product_id,
        quantity: guest_item.quantity,
        reserved_until: CartItem::RESERVATION_DURATION.from_now
      )
      guest_item.destroy
    end
  end
end
