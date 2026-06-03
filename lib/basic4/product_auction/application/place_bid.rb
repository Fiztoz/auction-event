require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/product"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"

module Basic4::ProductAuction::Application::PlaceBid
  module_function

  def call(bidder_id, product_id, amount_cents, container: Basic4::Container.production)
    repo, clock = container.values_at(:product_repository, :clock)

    product = repo.find_by_id(product_id)
    return Basic4::Result.failure(:product, "listing not found") unless product

    product.place_bid(bidder_id: bidder_id, amount_cents: coerce_int(amount_cents), now: clock.now)
           .tap_ok { |updated| repo.store(updated) }
  end

  def coerce_int(value)
    return value if value.is_a?(Integer)
    Integer(value.to_s, exception: false)
  end
end
