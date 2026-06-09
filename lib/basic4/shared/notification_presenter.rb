require_relative "shared"
require_relative "notification"

module Basic4::NotificationPresenter
  def self.call(notification)
    {
      id:         notification.id,
      user_id:    notification.user_id,
      type:       notification.type,
      title:      notification.title,
      body:       notification.body,
      related_id: notification.related_id,
      read:       notification.read,
      created_at: notification.created_at,
      read_at:    notification.read_at
    }
  end
end
