class CartItemsController < ApplicationController
  before_action :set_cart
  before_action :set_cart_item, only: [:update, :destroy]

  def create
    # Delegate to service
    @product = Product.find(params[:product_id])
    service = AddToCartService.call(
      cart: @cart,
      product: @product,
      quantity: params[:quantity]
    )

    if service.success?
      respond_to do |format|
        format.html { redirect_to cart_path, notice: "#{@product.name} added to cart!" }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to @product, alert: service.error_message }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: service.error_message }) }
      end
    end
  end

  def update
    # Delegate to service
    service = UpdateCartItemService.call(
      cart_item: @cart_item,
      quantity: params[:quantity]
    )

    if service.success?
      respond_to do |format|
        format.html { redirect_to cart_path, notice: "Cart updated" }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to cart_path, alert: service.error_message }
      end
    end
  end

  def destroy
    # Remove from cart (releases reservation immediately)
    @cart_item.destroy

    respond_to do |format|
      format.html { redirect_to cart_path, notice: "Item removed from cart" }
      format.turbo_stream
    end
  end

  private

  def set_cart
    if user_signed_in?
      @cart = current_user.cart || current_user.create_cart!
    else
      session_token = session[:cart_token] ||= SecureRandom.uuid
      @cart = Cart.find_or_create_by!(session_token: session_token, user_id: nil)
    end
  end

  def set_cart_item
    @cart_item = @cart.cart_items.find(params[:id])
  end
end
