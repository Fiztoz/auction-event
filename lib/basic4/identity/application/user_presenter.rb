require_relative "../../identity"
require_relative "../domain/user"

module Basic4::Identity::Application::UserPresenter
  def self.call(user)
    {
      id:             user.id,
      email:          user.email,
      name:           user.name,
      step:           user.step,
      email_verified: !!user.email_verification&.verified?,
      credit_score:   user.credit_score && {
        score:       user.credit_score.score,
        computed_at: user.credit_score.computed_at
      },
      created_at:     user.created_at
    }
  end
end
