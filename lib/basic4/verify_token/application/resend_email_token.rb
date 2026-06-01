require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/container"

module Basic4::VerifyToken::Application::ResendEmailToken
  module_function

  def call(user_id, container: Basic4::Container.production)
    repo, tokens, notifier, clock = container.values_at(
      :user_repository, :tokens, :notifier, :clock
    )

    user = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless user

    user.reissue_verification_token(token: tokens.email_token, at: clock.now)
        .tap_ok { |u|
          repo.store(u)
          notifier.email_verification_token(u.email, u.email_verification.token)
        }
  end
end
