require_relative "adapters"

module Basic4; module Identity; end; end

module Basic4::Identity::User
  ONBOARDING_STEPS = %w[signup verify_email credit_scoring done].freeze
  TOKEN_TTL_SECONDS = 15 * 60
  PASSWORD_RESET_TTL_SECONDS = 60 * 60
  EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
  MIN_PASSWORD_LENGTH = 8

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

  def self.find(user_id, repo: Basic4::Identity::Adapters::MongoUserRepo)
    doc = repo.find_by_id(user_id)
    doc && public_view(doc)
  end

  def self.generate_email_token(tokens: Basic4::Identity::Adapters::SecureRandomTokens)
    tokens.email_token
  end

  def self.log_email_token(email, token, notifier: Basic4::Identity::Adapters::StdoutNotifier)
    notifier.email_verification_token(email, token)
  end

  def self.log_password_reset_token(email, token, notifier: Basic4::Identity::Adapters::StdoutNotifier)
    notifier.password_reset_token(email, token)
  end
end
