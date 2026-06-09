require_relative "../shared"

# Persistence port for the Notification aggregate.
#
# Required module methods on adapters:
#   store(notification)             -> Basic4::Notification   (assigns id on insert)
#   find_by_id(id)                  -> Basic4::Notification | nil
#   find_for_user(user_id, limit:)  -> Array<Basic4::Notification>  (newest first)
#   mark_read(notification_id, at:) -> Basic4::Notification | nil   (nil if not found)
#   unread_count(user_id)           -> Integer
#   find_all_admins                 -> Array<Basic4::User>          (helper for fanning out to admins)
module Basic4::Ports::NotificationRepository
end
