# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # POST /users/sign_in
  def create
    super do |resource|
      # Merge guest cart into user cart after login using service
      if session[:cart_token].present?
        guest_cart = Cart.find_by(session_token: session[:cart_token], user_id: nil)
        if guest_cart
          user_cart = resource.cart || resource.create_cart!

          # Delegate to service
          MergeCartsService.call(
            user_cart: user_cart,
            guest_cart: guest_cart
          )

          session.delete(:cart_token)
        end
      end
    end
  end
end
