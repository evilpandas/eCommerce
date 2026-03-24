class Product < ApplicationRecord
  has_many_attached :images

  # Validations
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Set default price
  after_initialize :set_default_price, if: :new_record?

  private

  def set_default_price
    self.price ||= 10.00
  end
end
