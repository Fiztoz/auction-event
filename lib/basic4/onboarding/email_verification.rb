require_relative "../result"
require_relative "../identity/container"
require_relative "../identity/domain/user"

module Basic4; module Onboarding; end; end

module Basic4::Onboarding::EmailVerification
  module_function

  def verify(user_id, token:, container: Basic4::Identity::Container.production)
    repo, clock = container.values_at(:user_repository, :clock)

    user = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless user

    user.verify_email(submitted_token: token, at: clock.now)
        .tap_ok { |u| repo.store(u) }
  end

  def resend(user_id, container: Basic4::Identity::Container.production)
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
