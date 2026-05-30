require_relative "../result"
require_relative "user"
require_relative "inputs"
require_relative "ports"
require_relative "adapters"

module Basic4; module Identity; end; end

module Basic4::Identity::Registration
  module_function

  def signup(input,
             repo:     Basic4::Identity::Adapters::MongoUserRepo,
             hasher:   Basic4::Identity::Adapters::BcryptHasher,
             tokens:   Basic4::Identity::Adapters::SecureRandomTokens,
             notifier: Basic4::Identity::Adapters::StdoutNotifier,
             clock:    Basic4::Identity::Adapters::SystemClock)
    validate(normalize(input))
      .map    { |i| build_doc(i, hasher: hasher, tokens: tokens, clock: clock) }
      .bind   { |d| store(d, repo: repo) }
      .tap_ok { |d| notify_token(d, notifier: notifier) }
      .map    { |d| Basic4::Identity::User.public_view(d) }
  end

  def normalize(input)
    Basic4::Identity::Inputs::Signup.new(
      email:    input.email.to_s.strip.downcase,
      password: input.password.to_s,
      name:     input.name.to_s.strip
    )
  end

  def validate(input)
    unless input.email.match?(Basic4::Identity::User::EMAIL_REGEX)
      return Basic4::Result.failure(:email, "invalid email")
    end
    if input.password.length < Basic4::Identity::User::MIN_PASSWORD_LENGTH
      return Basic4::Result.failure(:password, "password must be #{Basic4::Identity::User::MIN_PASSWORD_LENGTH}+ chars")
    end
    return Basic4::Result.failure(:name, "name required") if input.name.empty?
    Basic4::Result.success(input)
  end

  def build_doc(input, hasher:, tokens:, clock:)
    now   = clock.now
    token = tokens.email_token
    {
      _id: tokens.user_id,
      email: input.email,
      name: input.name,
      password_hash: hasher.hash(input.password),
      step: "verify_email",
      email_verification: {
        token: token,
        expires_at: now + Basic4::Identity::User::TOKEN_TTL_SECONDS,
        verified_at: nil
      },
      credit_score: nil,
      created_at: now,
      updated_at: now
    }
  end

  def store(doc, repo:)
    repo.insert(doc)
    Basic4::Result.success(doc)
  rescue Basic4::Identity::Ports::UserRepository::DuplicateEmail
    Basic4::Result.failure(:email, "email already registered")
  end

  def notify_token(doc, notifier:)
    ev = doc[:email_verification]
    notifier.email_verification_token(doc[:email], ev[:token])
  end
end
