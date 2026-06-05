require "securerandom"
require_relative "../shared"

module Basic4::Infrastructure::SecureRandomTokenGenerator
  def self.user_id              = SecureRandom.uuid
  def self.product_id           = SecureRandom.uuid
  def self.settlement_id        = SecureRandom.uuid
  def self.email_token          = format("%06d", SecureRandom.random_number(1_000_000))
  def self.password_reset_token = SecureRandom.hex(16)
end
