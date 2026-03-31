class CartCleanupJob < ApplicationJob
  queue_as :default

  def perform
    # Remove expired cart item reservations
    expired_count = CartItem.expired_reservations.destroy_all.count

    # Log cleanup activity
    Rails.logger.info "CartCleanupJob: Removed #{expired_count} expired reservations"

    # Clean up old guest carts (30+ days old)
    old_guest_carts = Cart.guest.where("created_at < ?", 30.days.ago)
    old_count = old_guest_carts.destroy_all.count

    Rails.logger.info "CartCleanupJob: Removed #{old_count} old guest carts"
  end
end
