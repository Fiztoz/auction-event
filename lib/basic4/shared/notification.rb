require_relative "shared"

module Basic4
  # A notification is a message sent to a specific user about a domain event.
  # Notifications are used to inform users about actions they need to take or
  # about status changes (e.g., "Your product was approved").
  #
  # Notifications live in their own collection so they can be queried and
  # displayed independently of the entities they reference.
  Notification = Data.define(
    :id,            # UUID
    :user_id,       # Recipient
    :type,          # e.g., "product_pending_approval", "product_approved", "product_rejected"
    :title,         # Short title (shown in list)
    :body,          # Detailed message (shown in detail)
    :related_id,    # ID of related entity (e.g., product ID for navigation)
    :read,          # Boolean
    :created_at,
    :read_at        # nullable
  )
end

# Reopen Basic4::Notification to attach constants and factory directly to the
# class (same pattern as Basic4::User and Basic4::Product).
class Basic4::Notification
  # Notification type taxonomy. Adding a new type here documents the event
  # semantically and lets the front-end render appropriate icons/copy.
  TYPES = %w[
    product_pending_approval
    product_approved
    product_rejected
  ].freeze

  # Builds a fresh unread notification. The caller is responsible for
  # persisting it via the notification repository port.
  def self.create(user_id:, type:, title:, body:, related_id: nil, at:)
    new(
      id:         nil, # assigned by repo on store
      user_id:    user_id,
      type:       type,
      title:      title,
      body:       body,
      related_id: related_id,
      read:       false,
      created_at: at,
      read_at:    nil
    )
  end

  def mark_read(at:)
    return self if read
    with(read: true, read_at: at)
  end

  def unread?
    !read
  end
end
