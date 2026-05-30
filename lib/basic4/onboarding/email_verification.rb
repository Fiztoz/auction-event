require_relative "../result"
require_relative "../db"
require_relative "../identity/user"

module Basic4; module Onboarding; end; end

module Basic4::Onboarding::EmailVerification
  module_function

  def verify(user_id, token:)
    doc = Basic4::DB.users.find(_id: user_id).first
    return Basic4::Result.failure(:user, "user not found") unless doc
    return Basic4::Result.failure(:step, "not at email verification step") unless doc["step"] == "verify_email"

    ev = doc["email_verification"] || {}
    stored_token = ev["token"].to_s
    expires_at   = ev["expires_at"]
    submitted    = token.to_s.strip

    if stored_token.empty? || stored_token != submitted || expires_at.nil? || expires_at < Time.now.utc
      return Basic4::Result.failure(:token, "invalid or expired token")
    end

    now = Time.now.utc
    updated = Basic4::DB.users.find_one_and_update(
      { _id: user_id },
      { "$set" => {
          "email_verification.verified_at" => now,
          "step" => "credit_scoring",
          "updated_at" => now
      } },
      return_document: :after
    )
    Basic4::Result.success(Basic4::Identity::User.public_view(updated))
  end

  def resend(user_id)
    now = Time.now.utc
    token = Basic4::Identity::User.generate_email_token
    updated = Basic4::DB.users.find_one_and_update(
      { _id: user_id, step: "verify_email" },
      { "$set" => {
          "email_verification.token" => token,
          "email_verification.expires_at" => now + Basic4::Identity::User::TOKEN_TTL_SECONDS,
          "email_verification.verified_at" => nil,
          "updated_at" => now
      } },
      return_document: :after
    )
    unless updated
      existing = Basic4::DB.users.find(_id: user_id).first
      return Basic4::Result.failure(:user, "user not found") unless existing
      return Basic4::Result.failure(:step, "not at email verification step")
    end
    Basic4::Identity::User.log_email_token(updated["email"], token)
    Basic4::Result.success(Basic4::Identity::User.public_view(updated))
  end
end
