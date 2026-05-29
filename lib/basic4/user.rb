require "bcrypt"
require "securerandom"
require_relative "db"
require_relative "credit_scoring"

module Basic4
  module User
    ONBOARDING_STEPS = %w[signup verify_email credit_scoring done].freeze
    TOKEN_TTL_SECONDS = 15 * 60

    class ValidationError < StandardError
      attr_reader :field
      def initialize(field, message)
        @field = field
        super(message)
      end
    end

    def self.signup(email:, password:, name:)
      email = email.to_s.strip.downcase
      name = name.to_s.strip
      raise ValidationError.new(:email, "invalid email") unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
      raise ValidationError.new(:password, "password must be 8+ chars") if password.to_s.length < 8
      raise ValidationError.new(:name, "name required") if name.empty?

      now = Time.now.utc
      token = generate_token
      doc = {
        _id: SecureRandom.uuid,
        email: email,
        name: name,
        password_hash: BCrypt::Password.create(password),
        step: "verify_email",
        email_verification: {
          token: token,
          expires_at: now + TOKEN_TTL_SECONDS,
          verified_at: nil
        },
        credit_score: nil,
        created_at: now,
        updated_at: now
      }

      begin
        DB.users.insert_one(doc)
      rescue Mongo::Error::OperationFailure => e
        raise ValidationError.new(:email, "email already registered") if e.message.include?("E11000")
        raise
      end

      log_token(email, token)
      public_view(doc)
    end

    def self.resend_token(user_id)
      now = Time.now.utc
      token = generate_token
      updated = DB.users.find_one_and_update(
        { _id: user_id, step: "verify_email" },
        { "$set" => {
            "email_verification.token" => token,
            "email_verification.expires_at" => now + TOKEN_TTL_SECONDS,
            "email_verification.verified_at" => nil,
            "updated_at" => now
        } },
        return_document: :after
      )
      unless updated
        existing = DB.users.find(_id: user_id).first
        raise ValidationError.new(:user, "user not found") unless existing
        raise ValidationError.new(:step, "not at email verification step")
      end
      log_token(updated["email"], token)
      public_view(updated)
    end

    def self.verify_email_token(user_id, token:)
      token = token.to_s.strip
      doc = DB.users.find(_id: user_id).first
      raise ValidationError.new(:user, "user not found") unless doc
      raise ValidationError.new(:step, "not at email verification step") unless doc["step"] == "verify_email"

      ev = doc["email_verification"] || {}
      stored_token = ev["token"].to_s
      expires_at   = ev["expires_at"]

      if stored_token.empty? || stored_token != token || expires_at.nil? || expires_at < Time.now.utc
        raise ValidationError.new(:token, "invalid or expired token")
      end

      now = Time.now.utc
      updated = DB.users.find_one_and_update(
        { _id: user_id },
        { "$set" => {
            "email_verification.verified_at" => now,
            "step" => "credit_scoring",
            "updated_at" => now
        } },
        return_document: :after
      )
      public_view(updated)
    end

    def self.save_credit_score(user_id, income:, employment:, debt:, history_years:)
      doc = DB.users.find(_id: user_id).first
      raise ValidationError.new(:user, "user not found") unless doc
      raise ValidationError.new(:step, "not at credit scoring step") unless doc["step"] == "credit_scoring"

      begin
        inputs = Basic4::CreditScoring.validate!(
          income: income, employment: employment, debt: debt, history_years: history_years
        )
        score = Basic4::CreditScoring.score(**inputs)
      rescue Basic4::CreditScoring::InvalidInput => e
        raise ValidationError.new(e.field, e.message)
      end

      now = Time.now.utc
      updated = DB.users.find_one_and_update(
        { _id: user_id },
        { "$set" => {
            credit_score: { score: score, inputs: inputs, computed_at: now },
            step: "done",
            updated_at: now
        } },
        return_document: :after
      )
      public_view(updated)
    end

    def self.find(user_id)
      doc = DB.users.find(_id: user_id).first
      doc && public_view(doc)
    end

    def self.public_view(doc)
      ev = doc[:email_verification] || doc["email_verification"]
      cs = doc[:credit_score] || doc["credit_score"]
      {
        id:             doc[:_id] || doc["_id"],
        email:          doc[:email] || doc["email"],
        name:           doc[:name] || doc["name"],
        step:           doc[:step] || doc["step"],
        email_verified: !!(ev && (ev[:verified_at] || ev["verified_at"])),
        credit_score:   cs && {
          score:       cs[:score] || cs["score"],
          computed_at: cs[:computed_at] || cs["computed_at"]
        }
      }
    end

    def self.generate_token
      format("%06d", SecureRandom.random_number(1_000_000))
    end

    def self.log_token(email, token)
      $stdout.puts "[basic4] verification token for #{email}: #{token}"
      $stdout.flush
    end
  end
end
