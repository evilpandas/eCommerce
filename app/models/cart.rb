class Cart < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  before_create :generate_session_token

  # Scopes
  scope :guest, -> { where(user_id: nil) }
  scope :authenticated, -> { where.not(user_id: nil) }
  scope :expired, -> { where("expires_at < ?", Time.current) }

  # Simple calculations (stay in model)
  def total_price
    cart_items.includes(:product).sum { |item| item.product.price * item.quantity }
  end

  def total_items
    cart_items.sum(:quantity)
  end

  def guest?
    user_id.nil?
  end

  private

  def generate_session_token
    self.session_token ||= SecureRandom.uuid
  end
end
