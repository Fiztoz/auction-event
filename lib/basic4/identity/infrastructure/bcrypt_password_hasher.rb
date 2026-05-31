require "bcrypt"
require_relative "../../identity"

module Basic4::Identity::Infrastructure::BcryptPasswordHasher
  def self.hash(plain)
    BCrypt::Password.create(plain.to_s)
  end

  def self.verify(plain, stored)
    return false if stored.nil? || stored.to_s.empty?
    BCrypt::Password.new(stored) == plain.to_s
  end
end
