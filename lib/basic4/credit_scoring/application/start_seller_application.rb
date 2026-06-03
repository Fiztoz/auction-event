require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/ports/user_repository"
require_relative "../../shared/container"

module Basic4::CreditScoring::Application::StartSellerApplication
  module_function

  # A done buyer opts into selling: re-enters onboarding at the credit-scoring
  # step. Completing credit scoring (ComputeCreditScore) flips role to seller.
  def call(user_id, container: Basic4::Container.production)
    repo, clock = container.values_at(:user_repository, :clock)

    user = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless user

    user.start_seller_application(at: clock.now).tap_ok { |u| repo.store(u) }
  end
end
