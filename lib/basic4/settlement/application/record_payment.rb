require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/settlement"
require_relative "../../shared/ports/settlement_repository"
require_relative "../../shared/container"

# Admin records that the winner's payment has been received: invoiced -> paid.
module Basic4::Settlement::Application::RecordPayment
  module_function

  def call(settlement_id, container: Basic4::Container.production)
    repo, clock = container.values_at(:settlement_repository, :clock)

    settlement = repo.find_by_id(settlement_id)
    return Basic4::Result.failure(:settlement, "settlement not found") unless settlement

    settlement.record_payment(at: clock.now).tap_ok { |paid| repo.store(paid) }
  end
end
