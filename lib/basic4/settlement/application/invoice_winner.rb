require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/settlement"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/ports/settlement_repository"
require_relative "../../shared/container"

# Admin opens a settlement by invoicing the winner of an ended auction. Guards
# the cross-aggregate preconditions, then snapshots the order via Settlement.open.
module Basic4::Settlement::Application::InvoiceWinner
  module_function

  def call(product_id, container: Basic4::Container.production)
    product_repo, settlement_repo, user_repo, tokens, clock = container.values_at(
      :product_repository, :settlement_repository, :user_repository, :tokens, :clock
    )

    product = product_repo.find_by_id(product_id)
    return Basic4::Result.failure(:product, "auction not found") unless product
    return Basic4::Result.failure(:status, "auction has not ended") unless product.status == "ended"
    return Basic4::Result.failure(:winner, "auction has no winning bid") unless product.highest_bidder_id
    return Basic4::Result.failure(:settlement, "auction is already settled") if settlement_repo.find_by_product(product_id)

    buyer = user_repo.find_by_id(product.highest_bidder_id)
    return Basic4::Result.failure(:winner, "winning bidder not found") unless buyer

    settlement = Basic4::Settlement.open(
      id: tokens.settlement_id, product: product, buyer: buyer, at: clock.now
    )
    settlement_repo.store(settlement)
    Basic4::Result.success(settlement)
  end
end
