require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/product"
require_relative "../../shared/notification"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/ports/notification_repository"
require_relative "../../shared/container"

module Basic4::Admin::Application::ApproveProduct
  module_function

  def call(admin_id, product_id, container: Basic4::Container.production)
    repo, notif_repo, clock = container.values_at(:product_repository, :notification_repository, :clock)
    notifier = container[:notifier]

    product = repo.find_by_id(product_id)
    return Basic4::Result.failure(:product, "listing not found") unless product

    now = clock.now
    product.approve(at: now)
      .tap_ok { |approved| repo.store(approved) }
      .tap_ok { |approved| notify_seller(approved, notif_repo, notifier, clock, now) }
  end

  def notify_seller(product, notif_repo, notifier, clock, at)
    notification = Basic4::Notification.create(
      user_id:    product.seller_id,
      type:       "product_approved",
      title:      "Product approved!",
      body:       "Your product '#{product.title}' has been approved. You can now start the auction.",
      related_id: product.id,
      at:         at
    )
    notif_repo.store(notification)
    notifier.email_verification_token(product.seller_id, notification.id)
  end
end
