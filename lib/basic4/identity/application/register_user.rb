require_relative "../../identity"
require_relative "../../result"
require_relative "../domain/user"
require_relative "../ports/user_repository"
require_relative "../container"
require_relative "inputs"

module Basic4::Identity::Application::RegisterUser
  D     = Basic4::Identity::Domain
  Ports = Basic4::Identity::Ports

  module_function

  def call(input, container: Basic4::Identity::Container.production)
    repo, hasher, tokens, notifier, clock = container.values_at(
      :user_repository, :password_hasher, :tokens, :notifier, :clock
    )

    validate(normalize(input))
      .map    { |i| build_user(i, hasher: hasher, tokens: tokens, clock: clock) }
      .bind   { |u| store(u, repo: repo) }
      .tap_ok { |u| notifier.email_verification_token(u.email, u.email_verification.token) }
  end

  def normalize(input)
    Basic4::Identity::Application::Inputs::Signup.new(
      email:    input.email.to_s.strip.downcase,
      password: input.password.to_s,
      name:     input.name.to_s.strip
    )
  end

  def validate(input)
    unless input.email.match?(D::User::EMAIL_REGEX)
      return Basic4::Result.failure(:email, "invalid email")
    end
    if input.password.length < D::User::MIN_PASSWORD_LENGTH
      return Basic4::Result.failure(:password, "password must be #{D::User::MIN_PASSWORD_LENGTH}+ chars")
    end
    return Basic4::Result.failure(:name, "name required") if input.name.empty?
    Basic4::Result.success(input)
  end

  def build_user(input, hasher:, tokens:, clock:)
    D::User.register(
      id:                  tokens.user_id,
      email:               input.email,
      name:                input.name,
      password_hash:       hasher.hash(input.password),
      verification_token:  tokens.email_token,
      at:                  clock.now
    )
  end

  def store(user, repo:)
    repo.store(user)
    Basic4::Result.success(user)
  rescue Ports::UserRepository::DuplicateEmail
    Basic4::Result.failure(:email, "email already registered")
  end
end
