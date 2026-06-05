require_relative "../../shared/shared"
require_relative "../../shared/settlement"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/ports/bid_repository"
require_relative "../../shared/ports/settlement_repository"
require_relative "../../shared/container"

# Admin back-office read of a single closed auction: the product, its full bid
# history, the real identities of the seller and the winning buyer (the PII the
# admin needs to fulfil the order), and the settlement if one has been opened.
# Returns { product:, bids:, seller:, winner:, settlement: } or nil when the
# product doesn't exist. winner is nil when the auction had no bids.
module Basic4::Settlement::Application::AdminAuctionDetail
  module_function

  def call(product_id, container: Basic4::Container.production)
    product_repo, bid_repo, user_repo, settlement_repo = container.values_at(
      :product_repository, :bid_repository, :user_repository, :settlement_repository
    )

    product = product_repo.find_by_id(product_id)
    return nil unless product

    {
      product:    product,
      bids:       bid_repo.find_by_product(product_id),
      seller:     user_repo.find_by_id(product.seller_id),
      winner:     product.highest_bidder_id && user_repo.find_by_id(product.highest_bidder_id),
      settlement: settlement_repo.find_by_product(product_id)
    }
  end
end
