require "mongo"
require_relative "shared"

module Basic4::DB
  Mongo::Logger.logger.level = Logger::WARN

  def self.client
    @client ||= Mongo::Client.new(
      ENV.fetch("MONGO_URL", "mongodb://localhost:27017"),
      database: ENV.fetch("MONGO_DB", "basic4_onboarding")
    )
  end

  def self.users
    client[:users]
  end

  def self.products
    client[:products]
  end

  def self.bids
    client[:bids]
  end

  def self.settlements
    client[:settlements]
  end

  def self.notifications
    client[:notifications]
  end

  def self.ensure_indexes!
    users.indexes.create_one({ email: 1 }, unique: true)
    products.indexes.create_one({ seller_id: 1 })
    bids.indexes.create_one({ product_id: 1, created_at: -1 })
    settlements.indexes.create_one({ product_id: 1 }, unique: true)
    notifications.indexes.create_one({ user_id: 1, created_at: -1 })
    notifications.indexes.create_one({ user_id: 1, read: false })
  end
end
