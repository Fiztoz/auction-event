require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/notification"
require_relative "../../shared/ports/notification_repository"
require_relative "../../shared/container"

module Basic4::Identity::Application::ListNotifications
  module_function

  def call(user_id, limit: 50, container: Basic4::Container.production)
    repo = container[:notification_repository]
    Basic4::Result.success(notifications: repo.find_for_user(user_id, limit: limit),
                           unread_count: repo.unread_count(user_id))
  end
end
