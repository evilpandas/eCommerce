class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0 }

  before_create :set_reservation_expiry

  # Scopes
  scope :active_reservations, -> { where("reserved_until > ?", Time.current) }
  scope :expired_reservations, -> { where("reserved_until <= ?", Time.current) }

  # Constants
  RESERVATION_DURATION = 30.minutes

  # Simple helper methods (stay in model)
  def reservation_expired?
    reserved_until <= Time.current
  end

  def extend_reservation!
    update_column(:reserved_until, RESERVATION_DURATION.from_now)
  end

  def subtotal
    product.price * quantity
  end

  private

  def set_reservation_expiry
    self.reserved_until ||= RESERVATION_DURATION.from_now
  end
end
