require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/settlement"
require_relative "../../shared/ports/settlement_repository"
require_relative "../../shared/container"

# Admin records that the seller has shipped the item: paid -> shipped.
module Basic4::Settlement::Application::RecordShipment
  module_function

  def call(settlement_id, container: Basic4::Container.production)
    repo, clock = container.values_at(:settlement_repository, :clock)

    settlement = repo.find_by_id(settlement_id)
    return Basic4::Result.failure(:settlement, "settlement not found") unless settlement

    settlement.record_shipment(at: clock.now).tap_ok { |shipped| repo.store(shipped) }
  end
end
