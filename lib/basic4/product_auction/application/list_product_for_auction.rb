require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/product"
require_relative "../../shared/notification"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/ports/notification_repository"
require_relative "../../shared/container"
require_relative "inputs"

module Basic4::ProductAuction::Application::ListProductForAuction
  module_function

  def call(seller_id, input, container: Basic4::Container.production)
    repo, tokens, clock = container.values_at(:product_repository, :tokens, :clock)
    user_repo = container[:user_repository]
    notif_repo = container[:notification_repository]
    notifier = container[:notifier]

    i = Basic4::ProductAuction::Application::Normalize.call(input)
    Basic4::Product.create(
      id:                   tokens.product_id,
      seller_id:            seller_id,
      title:                i.title,
      description:          i.description,
      category:             i.category,
      starting_price_cents: i.starting_price_cents,
      duration_days:        i.duration_days,
      images:               i.images,
      at:                   clock.now
    ).tap_ok { |product| repo.store(product) }
     .tap_ok { |product| notify_admins(product, seller_id, user_repo, notif_repo, notifier, clock) }
  end

  # Fans out a "product_pending_approval" notification to every admin user.
  # We look up the seller's name to make the admin notification useful.
  def notify_admins(product, seller_id, user_repo, notif_repo, notifier, clock)
    seller = user_repo.find_by_id(seller_id)
    seller_name = seller&.name || "A seller"
    admin_ids = notif_repo.find_all_admins

    admin_ids.each do |admin_id|
      notification = Basic4::Notification.create(
        user_id:    admin_id,
        type:       "product_pending_approval",
        title:      "New product awaiting approval",
        body:       "#{seller_name} listed '#{product.title}' for review",
        related_id: product.id,
        at:         clock.now
      )
      notif_repo.store(notification)
      notifier.email_verification_token(admin_id, notification.id) # placeholder channel
    end
  end
end
