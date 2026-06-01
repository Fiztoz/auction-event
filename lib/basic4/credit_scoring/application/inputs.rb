require_relative "../../shared/shared"

module Basic4::CreditScoring::Application::Inputs
  CreditScoreSubmission = Data.define(:income, :employment, :debt, :history_years)
end
