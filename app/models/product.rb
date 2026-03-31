class Product < ApplicationRecord
  has_many_attached :images
  has_many :cart_items

  # Validations
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  def in_stock?
    stock_quantity > 0
  end

  def out_of_stock?
    stock_quantity <= 0
  end

  def available_quantity
    stock_quantity - reserved_quantity
  end

  def reserved_quantity
    CartItem.active_reservations
      .where(product_id: id)
      .sum(:quantity)
  end
end
