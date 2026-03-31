class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_cart

  def current_cart
    @current_cart ||= begin
      if user_signed_in?
        current_user.cart || current_user.create_cart!
      else
        session_token = session[:cart_token]
        Cart.find_by(session_token: session_token, user_id: nil) if session_token
      end
    end
  end
end
