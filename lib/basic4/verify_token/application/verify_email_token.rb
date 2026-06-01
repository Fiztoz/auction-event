require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/container"

module Basic4::VerifyToken::Application::VerifyEmailToken
  module_function

  def call(user_id, token:, container: Basic4::Container.production)
    repo, clock = container.values_at(:user_repository, :clock)

    user = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless user

    user.verify_email(submitted_token: token, at: clock.now)
        .tap_ok { |u| repo.store(u) }
  end
end
