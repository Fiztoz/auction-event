require "bcrypt"
require "securerandom"
require_relative "../db"
require_relative "ports"

module Basic4; module Identity; end; end

module Basic4::Identity::Adapters
  module MongoUserRepo
    DuplicateEmail = Basic4::Identity::Ports::UserRepository::DuplicateEmail

    def self.find_by_id(id)
      Basic4::DB.users.find(_id: id).first
    end

    def self.find_by_email(email)
      Basic4::DB.users.find(email: email).first
    end

    def self.find_by_password_reset_token(token)
      Basic4::DB.users.find("password_reset.token" => token).first
    end

    def self.insert(doc)
      Basic4::DB.users.insert_one(doc)
      doc
    rescue Mongo::Error::OperationFailure => e
      raise DuplicateEmail if e.message.include?("E11000")
      raise
    end

    def self.update(id, set: {}, unset: nil)
      ops = { "$set" => set }
      ops["$unset"] = unset if unset
      Basic4::DB.users.update_one({ _id: id }, ops)
      nil
    rescue Mongo::Error::OperationFailure => e
      raise DuplicateEmail if e.message.include?("E11000")
      raise
    end

    def self.find_one_and_update(id, set:)
      Basic4::DB.users.find_one_and_update({ _id: id }, { "$set" => set }, return_document: :after)
    rescue Mongo::Error::OperationFailure => e
      raise DuplicateEmail if e.message.include?("E11000")
      raise
    end
  end

  module BcryptHasher
    def self.hash(plain)
      BCrypt::Password.create(plain.to_s)
    end

    def self.verify(plain, stored)
      return false if stored.nil? || stored.to_s.empty?
      BCrypt::Password.new(stored) == plain.to_s
    end
  end

  module SecureRandomTokens
    def self.user_id              = SecureRandom.uuid
    def self.email_token          = format("%06d", SecureRandom.random_number(1_000_000))
    def self.password_reset_token = SecureRandom.hex(16)
  end

  module StdoutNotifier
    def self.email_verification_token(email, token, io: $stdout)
      io.puts "[basic4] verification token for #{email}: #{token}"
      io.flush
    end

    def self.password_reset_token(email, token, io: $stdout)
      io.puts "[basic4] password reset token for #{email}: #{token}"
      io.flush
    end
  end

  module SystemClock
    def self.now = Time.now.utc
  end
end
