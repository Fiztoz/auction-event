require_relative "../../identity"
require_relative "../../result"
require_relative "../domain/user"
require_relative "../container"
require_relative "inputs"

module Basic4::Identity::Application::ResetPassword
  D = Basic4::Identity::Domain

  module_function

  def call(input, container: Basic4::Identity::Container.production)
    repo, hasher, clock = container.values_at(:user_repository, :password_hasher, :clock)

    token = input.token.to_s.strip
    return Basic4::Result.failure(:token, "invalid or expired token") if token.empty?

    if input.new_password.to_s.length < D::User::MIN_PASSWORD_LENGTH
      return Basic4::Result.failure(:new_password, "password must be #{D::User::MIN_PASSWORD_LENGTH}+ chars")
    end

    user = repo.find_by_password_reset_token(token)
    return Basic4::Result.failure(:token, "invalid or expired token") unless user

    new_hash = hasher.hash(input.new_password)
    user.consume_password_reset(submitted_token: token, new_hash: new_hash, at: clock.now)
        .tap_ok { |u| repo.store(u) }
  end
end
