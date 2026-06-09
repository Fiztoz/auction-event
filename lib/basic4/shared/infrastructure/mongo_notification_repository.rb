require "securerandom"
require_relative "../shared"
require_relative "../db"
require_relative "../notification"
require_relative "../ports/notification_repository"

# MongoDB adapter for the Notification aggregate. Follows the same
# hydrate / serialize pattern as the other repositories.
module Basic4::Infrastructure::MongoNotificationRepository
  module_function

  def store(notification)
    id = notification.id || SecureRandom.uuid
    doc = serialize(notification).merge("_id" => id)
    Basic4::DB.notifications.insert_one(doc)
    hydrate(doc)
  end

  def find_by_id(id)
    doc = Basic4::DB.notifications.find(_id: id).first
    doc && hydrate(doc)
  end

  def find_for_user(user_id, limit: 50)
    Basic4::DB.notifications
      .find(user_id: user_id)
      .sort(created_at: -1)
      .limit(limit)
      .map { |doc| hydrate(doc) }
  end

  def mark_read(notification_id, at:)
    result = Basic4::DB.notifications.find_one_and_update(
      { _id: notification_id },
      { "$set" => { read: true, read_at: at } },
      return_document: :after
    )
    result && hydrate(result)
  end

  def unread_count(user_id)
    Basic4::DB.notifications.count_documents(user_id: user_id, read: false)
  end

  # Helper: returns all user IDs with role == "admin" so the application
  # layer can fan out a notification without depending on a user repository
  # port directly.
  def find_all_admins
    Basic4::DB.users.find(role: "admin", step: "done").to_a.map do |doc|
      doc["_id"]
    end
  end

  def hydrate(doc)
    Basic4::Notification.new(
      id:         doc["_id"],
      user_id:    doc["user_id"],
      type:       doc["type"],
      title:      doc["title"],
      body:       doc["body"],
      related_id: doc["related_id"],
      read:       doc["read"] || false,
      created_at: doc["created_at"],
      read_at:    doc["read_at"]
    )
  end

  def serialize(notification)
    {
      "user_id"    => notification.user_id,
      "type"       => notification.type,
      "title"      => notification.title,
      "body"       => notification.body,
      "related_id" => notification.related_id,
      "read"       => notification.read,
      "created_at" => notification.created_at,
      "read_at"    => notification.read_at
    }
  end
end
