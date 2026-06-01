require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/ports/user_repository"
require_relative "../../shared/container"
require_relative "inputs"

module Basic4::Identity::Application::UpdateProfile
  module_function

  def call(user_id, input, container: Basic4::Container.production)
    repo, hasher, tokens, notifier, clock = container.values_at(
      :user_repository, :password_hasher, :tokens, :notifier, :clock
    )

    user = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless user

    name_change     = input.name.is_a?(String)         ? input.name        : nil
    email_change    = input.email.is_a?(String)        ? input.email       : nil
    changing_password = input.new_password.is_a?(String) && !input.new_password.empty?

    new_email_normalized = email_change && email_change.strip.downcase
    changing_email    = new_email_normalized && !new_email_normalized.empty? && new_email_normalized != user.email

    if changing_password && input.new_password.length < Basic4::User::MIN_PASSWORD_LENGTH
      return Basic4::Result.failure(:new_password, "password must be #{Basic4::User::MIN_PASSWORD_LENGTH}+ chars")
    end

    if changing_email || changing_password
      if input.current_password.to_s.empty?
        return Basic4::Result.failure(:current_password, "current password required")
      end
      unless hasher.verify(input.current_password.to_s, user.password_hash)
        return Basic4::Result.failure(:current_password, "current password is incorrect")
      end
    end

    if name_change
      result = user.change_name(name_change, at: clock.now)
      return result if result.failure?
      user = result.value
    end

    if changing_password
      result = user.change_password(hasher.hash(input.new_password), at: clock.now)
      return result if result.failure?
      user = result.value
    end

    new_email_token = nil
    if changing_email
      new_email_token = tokens.email_token
      result = user.change_email(email_change, token: new_email_token, at: clock.now)
      return result if result.failure?
      user = result.value
    end

    begin
      repo.store(user)
    rescue Basic4::Ports::UserRepository::DuplicateEmail
      return Basic4::Result.failure(:email, "email already registered")
    end

    notifier.email_verification_token(user.email, new_email_token) if changing_email

    Basic4::Result.success(user)
  end
end
