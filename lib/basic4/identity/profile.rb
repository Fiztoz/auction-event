require_relative "../result"
require_relative "user"
require_relative "inputs"
require_relative "ports"
require_relative "adapters"

module Basic4; module Identity; end; end

module Basic4::Identity::Profile
  Change = Data.define(:new_name, :new_email, :current_password, :new_password,
                       :changing_email, :changing_password)

  module_function

  def update(user_id, input,
             repo:     Basic4::Identity::Adapters::MongoUserRepo,
             hasher:   Basic4::Identity::Adapters::BcryptHasher,
             tokens:   Basic4::Identity::Adapters::SecureRandomTokens,
             notifier: Basic4::Identity::Adapters::StdoutNotifier,
             clock:    Basic4::Identity::Adapters::SystemClock)
    current = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless current

    changes = decide_changes(input, current)

    validation = validate(changes, current, hasher: hasher)
    return validation if validation.failure?

    set, new_token = build_set(changes, hasher: hasher, tokens: tokens, clock: clock)

    apply_result = apply(user_id, set, repo: repo)
    return apply_result if apply_result.failure?

    notify_if_email_change(changes, new_token, notifier: notifier)
    Basic4::Result.success(Basic4::Identity::User.public_view(apply_result.value))
  end

  def decide_changes(input, current)
    new_name  = input.name.is_a?(String)  ? input.name.strip          : nil
    new_email = input.email.is_a?(String) ? input.email.strip.downcase : nil
    changing_email    = new_email && !new_email.empty? && new_email != current["email"]
    changing_password = input.new_password.is_a?(String) && !input.new_password.empty?

    Change.new(
      new_name:          new_name,
      new_email:         new_email,
      current_password:  input.current_password,
      new_password:      input.new_password,
      changing_email:    changing_email,
      changing_password: changing_password
    )
  end

  def validate(c, current, hasher:)
    if c.new_name && c.new_name.empty?
      return Basic4::Result.failure(:name, "name cannot be empty")
    end
    if c.changing_email && !c.new_email.match?(Basic4::Identity::User::EMAIL_REGEX)
      return Basic4::Result.failure(:email, "invalid email")
    end
    if c.changing_password && c.new_password.length < Basic4::Identity::User::MIN_PASSWORD_LENGTH
      return Basic4::Result.failure(:new_password, "password must be #{Basic4::Identity::User::MIN_PASSWORD_LENGTH}+ chars")
    end
    if c.changing_email || c.changing_password
      if c.current_password.to_s.empty?
        return Basic4::Result.failure(:current_password, "current password required")
      end
      unless hasher.verify(c.current_password.to_s, current["password_hash"])
        return Basic4::Result.failure(:current_password, "current password is incorrect")
      end
    end
    Basic4::Result.success(c)
  end

  def build_set(c, hasher:, tokens:, clock:)
    now = clock.now
    set = { "updated_at" => now }
    set["name"]          = c.new_name if c.new_name && !c.new_name.empty?
    set["password_hash"] = hasher.hash(c.new_password) if c.changing_password

    new_token = nil
    if c.changing_email
      new_token = tokens.email_token
      set["email"] = c.new_email
      set["step"]  = "verify_email"
      set["email_verification"] = {
        "token" => new_token,
        "expires_at" => now + Basic4::Identity::User::TOKEN_TTL_SECONDS,
        "verified_at" => nil
      }
    end
    [set, new_token]
  end

  def apply(user_id, set, repo:)
    updated = repo.find_one_and_update(user_id, set: set)
    Basic4::Result.success(updated)
  rescue Basic4::Identity::Ports::UserRepository::DuplicateEmail
    Basic4::Result.failure(:email, "email already registered")
  end

  def notify_if_email_change(c, new_token, notifier:)
    return unless c.changing_email
    notifier.email_verification_token(c.new_email, new_token)
  end
end
