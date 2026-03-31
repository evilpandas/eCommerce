class CartsController < ApplicationController
  before_action :set_cart

  def show
    # Main cart page
    @cart_items = @cart.cart_items.includes(:product).active_reservations

    # Clean up any expired items
    @cart.cart_items.expired_reservations.destroy_all
  end

  private

  def set_cart
    if user_signed_in?
      @cart = current_user.cart || current_user.create_cart!
    else
      # Guest cart logic
      session_token = session[:cart_token] ||= SecureRandom.uuid
      @cart = Cart.find_or_create_by!(session_token: session_token, user_id: nil)
    end
  end
end
