require_relative "shared"
require_relative "result"

module Basic4
  EmailVerification = Data.define(:token, :expires_at, :verified_at) do
    def verified?
      !verified_at.nil?
    end

    def expired?(at:)
      expires_at.nil? || expires_at < at
    end

    def matches?(submitted, at:)
      stored = token.to_s
      !stored.empty? && stored == submitted.to_s.strip && !expired?(at: at)
    end

    def complete(at:)
      with(verified_at: at)
    end
  end

  CreditScoreSnapshot = Data.define(:score, :inputs, :computed_at)

  PasswordReset = Data.define(:token, :expires_at) do
    def expired?(at:)
      expires_at.nil? || expires_at < at
    end

    def matches?(submitted)
      stored = token.to_s
      !stored.empty? && stored == submitted.to_s.strip
    end
  end

  User = Data.define(
    :id, :email, :name, :password_hash, :step,
    :email_verification, :credit_score, :password_reset,
    :created_at, :updated_at
  )
end

# Reopen Basic4::User to attach constants and behaviors directly to the class.
# Constants assigned inside a `Data.define do ... end` block leak to the lexical
# scope (Basic4), not to the Data class itself — so they wouldn't be reachable
# as `Basic4::User::EMAIL_REGEX` from other files. Defining them in a normal
# class body keeps them where callers expect.
class Basic4::User
  EMAIL_REGEX                = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
  MIN_PASSWORD_LENGTH        = 8
  TOKEN_TTL_SECONDS          = 15 * 60
  PASSWORD_RESET_TTL_SECONDS = 60 * 60
  ONBOARDING_STEPS           = %w[signup verify_email credit_scoring done].freeze

  def self.register(id:, email:, name:, password_hash:, verification_token:, at:)
    new(
      id: id, email: email, name: name, password_hash: password_hash,
      step: "verify_email",
      email_verification: Basic4::EmailVerification.new(
        token: verification_token,
        expires_at: at + TOKEN_TTL_SECONDS,
        verified_at: nil
      ),
      credit_score: nil,
      password_reset: nil,
      created_at: at,
      updated_at: at
    )
  end

  def verify_email(submitted_token:, at:)
    return Basic4::Result.failure(:step, "not at email verification step") unless step == "verify_email"
    unless email_verification && email_verification.matches?(submitted_token, at: at)
      return Basic4::Result.failure(:token, "invalid or expired token")
    end
    Basic4::Result.success(with(
      email_verification: email_verification.complete(at: at),
      step: "credit_scoring",
      updated_at: at
    ))
  end

  def reissue_verification_token(token:, at:)
    return Basic4::Result.failure(:step, "not at email verification step") unless step == "verify_email"
    Basic4::Result.success(with(
      email_verification: Basic4::EmailVerification.new(
        token: token, expires_at: at + TOKEN_TTL_SECONDS, verified_at: nil
      ),
      updated_at: at
    ))
  end

  def apply_credit_score(score:, inputs:, at:)
    return Basic4::Result.failure(:step, "not at credit scoring step") unless step == "credit_scoring"
    Basic4::Result.success(with(
      credit_score: Basic4::CreditScoreSnapshot.new(score: score, inputs: inputs, computed_at: at),
      step: "done",
      updated_at: at
    ))
  end

  def change_name(new_name, at:)
    stripped = new_name.to_s.strip
    return Basic4::Result.failure(:name, "name cannot be empty") if stripped.empty?
    Basic4::Result.success(with(name: stripped, updated_at: at))
  end

  def change_email(new_email, token:, at:)
    normalized = new_email.to_s.strip.downcase
    return Basic4::Result.failure(:email, "invalid email") unless normalized.match?(EMAIL_REGEX)
    Basic4::Result.success(with(
      email: normalized,
      step: "verify_email",
      email_verification: Basic4::EmailVerification.new(
        token: token, expires_at: at + TOKEN_TTL_SECONDS, verified_at: nil
      ),
      updated_at: at
    ))
  end

  def change_password(new_hash, at:)
    Basic4::Result.success(with(password_hash: new_hash, updated_at: at))
  end

  def issue_password_reset(token:, at:)
    with(password_reset: Basic4::PasswordReset.new(
      token: token, expires_at: at + PASSWORD_RESET_TTL_SECONDS
    ), updated_at: at)
  end

  def consume_password_reset(submitted_token:, new_hash:, at:)
    unless password_reset && password_reset.matches?(submitted_token) && !password_reset.expired?(at: at)
      return Basic4::Result.failure(:token, "invalid or expired token")
    end
    Basic4::Result.success(with(
      password_hash: new_hash,
      password_reset: nil,
      updated_at: at
    ))
  end
end
