require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/container"
require_relative "../domain/scoring"
require_relative "inputs"

module Basic4::CreditScoring::Application::ComputeCreditScore
  module_function

  def call(user_id, input, container: Basic4::Container.production)
    repo, clock = container.values_at(:user_repository, :clock)

    user = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless user

    begin
      normalized = Basic4::CreditScoring::Domain::Scoring.validate!(
        income:        input.income,
        employment:    input.employment,
        debt:          input.debt,
        history_years: input.history_years
      )
      score = Basic4::CreditScoring::Domain::Scoring.score(**normalized)
    rescue Basic4::CreditScoring::Domain::Scoring::InvalidInput => e
      return Basic4::Result.failure(e.field, e.message)
    end

    user.apply_credit_score(score: score, inputs: normalized, at: clock.now)
        .tap_ok { |u| repo.store(u) }
  end
end
