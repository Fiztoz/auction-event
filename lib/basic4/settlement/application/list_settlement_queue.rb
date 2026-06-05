require_relative "../../shared/shared"
require_relative "../../shared/settlement"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/ports/settlement_repository"
require_relative "../../shared/container"

# Admin back-office queue: every closed auction that has a winner, with its
# winner and current settlement (nil when not yet invoiced). Drives the
# top-level "Settlements" page so the admin can see, at a glance, what needs
# action. A read with no failure mode -> plain Array of Hashes, most-recently
# ended first (the order find_closed already returns).
module Basic4::Settlement::Application::ListSettlementQueue
  module_function

  def call(container: Basic4::Container.production)
    product_repo, user_repo, settlement_repo = container.values_at(
      :product_repository, :user_repository, :settlement_repository
    )

    product_repo.find_closed.select(&:highest_bidder_id).map do |product|
      {
        product:    product,
        winner:     user_repo.find_by_id(product.highest_bidder_id),
        settlement: settlement_repo.find_by_product(product.id)
      }
    end
  end
end
