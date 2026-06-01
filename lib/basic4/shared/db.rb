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

  def self.ensure_indexes!
    users.indexes.create_one({ email: 1 }, unique: true)
  end
end
