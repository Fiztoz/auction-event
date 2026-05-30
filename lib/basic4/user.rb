require "bcrypt"
require "securerandom"
require_relative "db"
require_relative "credit_scoring"

module Basic4
  module User
    ONBOARDING_STEPS = %w[signup verify_email credit_scoring done].freeze
    TOKEN_TTL_SECONDS = 15 * 60
    PASSWORD_RESET_TTL_SECONDS = 60 * 60
    EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
    MIN_PASSWORD_LENGTH = 8

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
      raise ValidationError.new(:email, "invalid email") unless email.match?(EMAIL_REGEX)
      raise ValidationError.new(:password, "password must be #{MIN_PASSWORD_LENGTH}+ chars") if password.to_s.length < MIN_PASSWORD_LENGTH
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

    def self.authenticate(email:, password:)
      email = email.to_s.strip.downcase
      doc = DB.users.find(email: email).first
      raise ValidationError.new(:credentials, "invalid email or password") unless doc
      hash = doc["password_hash"] || doc[:password_hash]
      unless hash && BCrypt::Password.new(hash) == password.to_s
        raise ValidationError.new(:credentials, "invalid email or password")
      end
      public_view(doc)
    end

    def self.update_profile(user_id, name: nil, email: nil, current_password: nil, new_password: nil)
      doc = DB.users.find(_id: user_id).first
      raise ValidationError.new(:user, "user not found") unless doc

      new_name  = name.is_a?(String) ? name.strip : nil
      new_email = email.is_a?(String) ? email.strip.downcase : nil
      changing_email    = new_email && !new_email.empty? && new_email != doc["email"]
      changing_password = new_password.is_a?(String) && !new_password.empty?

      if new_name && new_name.empty?
        raise ValidationError.new(:name, "name cannot be empty")
      end

      if changing_email && !new_email.match?(EMAIL_REGEX)
        raise ValidationError.new(:email, "invalid email")
      end

      if changing_password && new_password.length < MIN_PASSWORD_LENGTH
        raise ValidationError.new(:new_password, "password must be #{MIN_PASSWORD_LENGTH}+ chars")
      end

      if changing_email || changing_password
        if current_password.to_s.empty?
          raise ValidationError.new(:current_password, "current password required")
        end
        unless BCrypt::Password.new(doc["password_hash"]) == current_password.to_s
          raise ValidationError.new(:current_password, "current password is incorrect")
        end
      end

      now = Time.now.utc
      updates = { "updated_at" => now }
      updates["name"] = new_name if new_name && !new_name.empty?
      updates["password_hash"] = BCrypt::Password.create(new_password) if changing_password

      if changing_email
        token = generate_token
        updates["email"] = new_email
        updates["step"]  = "verify_email"
        updates["email_verification"] = {
          "token" => token,
          "expires_at" => now + TOKEN_TTL_SECONDS,
          "verified_at" => nil
        }
      end

      begin
        updated = DB.users.find_one_and_update(
          { _id: user_id },
          { "$set" => updates },
          return_document: :after
        )
      rescue Mongo::Error::OperationFailure => e
        raise ValidationError.new(:email, "email already registered") if e.message.include?("E11000")
        raise
      end

      log_token(new_email, token) if changing_email
      public_view(updated)
    end

    def self.request_password_reset(email)
      email = email.to_s.strip.downcase
      return false unless email.match?(EMAIL_REGEX)

      doc = DB.users.find(email: email).first
      return false unless doc

      token = SecureRandom.hex(16)
      now = Time.now.utc
      DB.users.update_one(
        { _id: doc["_id"] },
        { "$set" => {
            "password_reset" => {
              "token" => token,
              "expires_at" => now + PASSWORD_RESET_TTL_SECONDS
            },
            "updated_at" => now
        } }
      )
      log_password_reset(email, token)
      true
    end

    def self.reset_password(token:, new_password:)
      token = token.to_s.strip
      raise ValidationError.new(:token, "invalid or expired token") if token.empty?

      if new_password.to_s.length < MIN_PASSWORD_LENGTH
        raise ValidationError.new(:new_password, "password must be #{MIN_PASSWORD_LENGTH}+ chars")
      end

      doc = DB.users.find("password_reset.token" => token).first
      raise ValidationError.new(:token, "invalid or expired token") unless doc

      pr = doc["password_reset"] || {}
      expires_at = pr["expires_at"]
      if expires_at.nil? || expires_at < Time.now.utc
        raise ValidationError.new(:token, "invalid or expired token")
      end

      now = Time.now.utc
      DB.users.update_one(
        { _id: doc["_id"] },
        {
          "$set"   => { "password_hash" => BCrypt::Password.create(new_password), "updated_at" => now },
          "$unset" => { "password_reset" => "" }
        }
      )
      true
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
        },
        created_at:     doc[:created_at] || doc["created_at"]
      }
    end

    def self.generate_token
      format("%06d", SecureRandom.random_number(1_000_000))
    end

    def self.log_token(email, token)
      $stdout.puts "[basic4] verification token for #{email}: #{token}"
      $stdout.flush
    end

    def self.log_password_reset(email, token)
      $stdout.puts "[basic4] password reset token for #{email}: #{token}"
      $stdout.flush
    end
  end
end
