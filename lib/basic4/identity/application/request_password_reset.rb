require_relative "../../identity"
require_relative "../domain/user"
require_relative "../container"
require_relative "inputs"

module Basic4::Identity::Application::RequestPasswordReset
  D = Basic4::Identity::Domain

  module_function

  # Always returns Boolean — never reveals whether the email is registered.
  def call(input, container: Basic4::Identity::Container.production)
    repo, tokens, notifier, clock = container.values_at(
      :user_repository, :tokens, :notifier, :clock
    )

    email = input.email.to_s.strip.downcase
    return false unless email.match?(D::User::EMAIL_REGEX)

    user = repo.find_by_email(email)
    return false unless user

    token   = tokens.password_reset_token
    updated = user.issue_password_reset(token: token, at: clock.now)
    repo.store(updated)
    notifier.password_reset_token(email, token)
    true
  end
end
