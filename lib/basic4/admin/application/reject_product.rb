require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/product"
require_relative "../../shared/notification"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/ports/notification_repository"
require_relative "../../shared/container"

module Basic4::Admin::Application::RejectProduct
  module_function

  def call(admin_id, product_id, reason:, container: Basic4::Container.production)
    repo, notif_repo, clock = container.values_at(:product_repository, :notification_repository, :clock)
    notifier = container[:notifier]

    product = repo.find_by_id(product_id)
    return Basic4::Result.failure(:product, "listing not found") unless product

    now = clock.now
    product.reject(reason: reason, at: now)
      .tap_ok { |rejected| repo.store(rejected) }
      .tap_ok { |rejected| notify_seller(rejected, reason, notif_repo, notifier, clock, now) }
  end

  def notify_seller(product, reason, notif_repo, notifier, clock, at)
    notification = Basic4::Notification.create(
      user_id:    product.seller_id,
      type:       "product_rejected",
      title:      "Product needs changes",
      body:       "Your product '#{product.title}' was not approved. Reason: #{reason}",
      related_id: product.id,
      at:         at
    )
    notif_repo.store(notification)
    notifier.email_verification_token(product.seller_id, notification.id)
  end
end
