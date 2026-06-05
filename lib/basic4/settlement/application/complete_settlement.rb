require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/settlement"
require_relative "../../shared/ports/settlement_repository"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"

# Admin releases funds to the seller and closes the order: shipped -> completed.
# Completing a settlement also marks the underlying auction as completed.
module Basic4::Settlement::Application::CompleteSettlement
  module_function

  def call(settlement_id, container: Basic4::Container.production)
    settlement_repo, product_repo, clock = container.values_at(
      :settlement_repository, :product_repository, :clock
    )

    settlement = settlement_repo.find_by_id(settlement_id)
    return Basic4::Result.failure(:settlement, "settlement not found") unless settlement

    now = clock.now
    settlement.complete(at: now)
              .tap_ok { |done| settlement_repo.store(done) }
              .tap_ok { |done| complete_auction(product_repo, done.product_id, now) }
  end

  def complete_auction(product_repo, product_id, now)
    product = product_repo.find_by_id(product_id)
    product&.mark_completed(at: now)&.tap_ok { |completed| product_repo.store(completed) }
  end
end
