require_relative "../result"
require_relative "user"
require_relative "inputs"
require_relative "adapters"

module Basic4; module Identity; end; end

module Basic4::Identity::PasswordReset
  module_function

  # ── request a token ────────────────────────────────────────────
  # Boolean return — never leaks whether the email is registered.
  # The route always responds 200 { ok: true } regardless of value.

  def request(input,
              repo:     Basic4::Identity::Adapters::MongoUserRepo,
              tokens:   Basic4::Identity::Adapters::SecureRandomTokens,
              notifier: Basic4::Identity::Adapters::StdoutNotifier,
              clock:    Basic4::Identity::Adapters::SystemClock)
    email = input.email.to_s.strip.downcase
    return false unless email.match?(Basic4::Identity::User::EMAIL_REGEX)

    doc = repo.find_by_email(email)
    return false unless doc

    token = tokens.password_reset_token
    now   = clock.now
    repo.update(doc["_id"], set: {
      "password_reset" => {
        "token" => token,
        "expires_at" => now + Basic4::Identity::User::PASSWORD_RESET_TTL_SECONDS
      },
      "updated_at" => now
    })
    notifier.password_reset_token(email, token)
    true
  end

  # ── consume a token ────────────────────────────────────────────

  def reset(input,
            repo:   Basic4::Identity::Adapters::MongoUserRepo,
            hasher: Basic4::Identity::Adapters::BcryptHasher,
            clock:  Basic4::Identity::Adapters::SystemClock)
    validate_input(input)
      .bind { |i|     find_doc(i, repo: repo) }
      .bind { |(d, i)| check_expiry(d, clock: clock).map { [d, i] } }
      .bind { |(d, i)| persist(d, i, repo: repo, hasher: hasher, clock: clock) }
  end

  def validate_input(input)
    token = input.token.to_s.strip
    return Basic4::Result.failure(:token, "invalid or expired token") if token.empty?
    if input.new_password.to_s.length < Basic4::Identity::User::MIN_PASSWORD_LENGTH
      return Basic4::Result.failure(:new_password, "password must be #{Basic4::Identity::User::MIN_PASSWORD_LENGTH}+ chars")
    end
    Basic4::Result.success(
      Basic4::Identity::Inputs::PasswordResetSubmit.new(token: token, new_password: input.new_password)
    )
  end

  def find_doc(input, repo:)
    doc = repo.find_by_password_reset_token(input.token)
    return Basic4::Result.failure(:token, "invalid or expired token") unless doc
    Basic4::Result.success([doc, input])
  end

  def check_expiry(doc, clock:)
    pr = doc["password_reset"] || {}
    expires_at = pr["expires_at"]
    if expires_at.nil? || expires_at < clock.now
      return Basic4::Result.failure(:token, "invalid or expired token")
    end
    Basic4::Result.success(doc)
  end

  def persist(doc, input, repo:, hasher:, clock:)
    repo.update(
      doc["_id"],
      set:   { "password_hash" => hasher.hash(input.new_password), "updated_at" => clock.now },
      unset: { "password_reset" => "" }
    )
    Basic4::Result.success(true)
  end
end
