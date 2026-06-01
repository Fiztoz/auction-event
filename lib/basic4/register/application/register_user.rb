require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/ports/user_repository"
require_relative "../../shared/container"
require_relative "inputs"

module Basic4::Register::Application::RegisterUser
  module_function

  def call(input, container: Basic4::Container.production)
    repo, hasher, tokens, notifier, clock = container.values_at(
      :user_repository, :password_hasher, :tokens, :notifier, :clock
    )

    validate(normalize(input))
      .map    { |i| build_user(i, hasher: hasher, tokens: tokens, clock: clock) }
      .bind   { |u| store(u, repo: repo) }
      .tap_ok { |u| notifier.email_verification_token(u.email, u.email_verification.token) }
  end

  def normalize(input)
    Basic4::Register::Application::Inputs::Signup.new(
      email:    input.email.to_s.strip.downcase,
      password: input.password.to_s,
      name:     input.name.to_s.strip
    )
  end

  def validate(input)
    unless input.email.match?(Basic4::User::EMAIL_REGEX)
      return Basic4::Result.failure(:email, "invalid email")
    end
    if input.password.length < Basic4::User::MIN_PASSWORD_LENGTH
      return Basic4::Result.failure(:password, "password must be #{Basic4::User::MIN_PASSWORD_LENGTH}+ chars")
    end
    return Basic4::Result.failure(:name, "name required") if input.name.empty?
    Basic4::Result.success(input)
  end

  def build_user(input, hasher:, tokens:, clock:)
    Basic4::User.register(
      id:                 tokens.user_id,
      email:              input.email,
      name:               input.name,
      password_hash:      hasher.hash(input.password),
      verification_token: tokens.email_token,
      at:                 clock.now
    )
  end

  def store(user, repo:)
    repo.store(user)
    Basic4::Result.success(user)
  rescue Basic4::Ports::UserRepository::DuplicateEmail
    Basic4::Result.failure(:email, "email already registered")
  end
end
