require_relative "../result"
require_relative "../scoring"
require_relative "../identity/container"
require_relative "../identity/domain/user"

module Basic4; module Onboarding; end; end

module Basic4::Onboarding::CreditScoring
  module_function

  def save(user_id, income:, employment:, debt:, history_years:,
           container: Basic4::Identity::Container.production)
    repo, clock = container.values_at(:user_repository, :clock)

    user = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless user

    begin
      inputs = Basic4::Scoring.validate!(
        income: income, employment: employment, debt: debt, history_years: history_years
      )
      score = Basic4::Scoring.score(**inputs)
    rescue Basic4::Scoring::InvalidInput => e
      return Basic4::Result.failure(e.field, e.message)
    end

    user.apply_credit_score(score: score, inputs: inputs, at: clock.now)
        .tap_ok { |u| repo.store(u) }
  end
end
