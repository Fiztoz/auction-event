require_relative "../db"
require_relative "../errors"
require_relative "../identity/user"

module Basic4
  module Onboarding
    module EmailVerification
      def self.verify(user_id, token:)
        token = token.to_s.strip
        doc = Basic4::DB.users.find(_id: user_id).first
        raise Basic4::ValidationError.new(:user, "user not found") unless doc
        raise Basic4::ValidationError.new(:step, "not at email verification step") unless doc["step"] == "verify_email"

        ev = doc["email_verification"] || {}
        stored_token = ev["token"].to_s
        expires_at   = ev["expires_at"]

        if stored_token.empty? || stored_token != token || expires_at.nil? || expires_at < Time.now.utc
          raise Basic4::ValidationError.new(:token, "invalid or expired token")
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
        Basic4::Identity::User.public_view(updated)
      end

      def self.resend(user_id)
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
          raise Basic4::ValidationError.new(:user, "user not found") unless existing
          raise Basic4::ValidationError.new(:step, "not at email verification step")
        end
        Basic4::Identity::User.log_email_token(updated["email"], token)
        Basic4::Identity::User.public_view(updated)
      end
    end
  end
end
