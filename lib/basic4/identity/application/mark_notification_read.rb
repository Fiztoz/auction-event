require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/notification"
require_relative "../../shared/ports/notification_repository"
require_relative "../../shared/container"

module Basic4::Identity::Application::MarkNotificationRead
  module_function

  def call(user_id, notification_id, container: Basic4::Container.production)
    repo, clock = container.values_at(:notification_repository, :clock)

    notification = repo.find_by_id(notification_id)
    return Basic4::Result.failure(:notification, "not found") unless notification
    return Basic4::Result.failure(:notification, "not your notification") if notification.user_id != user_id

    Basic4::Result.success(repo.mark_read(notification_id, at: clock.now))
  end
end
