require "securerandom"
require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/product"
require_relative "../../shared/bid"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/ports/bid_repository"
require_relative "../../shared/container"

module Basic4::ProductAuction::Application::PlaceBid
  module_function

  def call(bidder_id, product_id, amount_cents, container: Basic4::Container.production)
    product_repo, bid_repo, user_repo, clock = container.values_at(
      :product_repository, :bid_repository, :user_repository, :clock
    )

    product = product_repo.find_by_id(product_id)
    return Basic4::Result.failure(:product, "listing not found") unless product

    now    = clock.now
    amount = coerce_int(amount_cents)

    product.place_bid(bidder_id: bidder_id, amount_cents: amount, now: now)
           .tap_ok { |updated| product_repo.store(updated) }
           .tap_ok { record_bid(bid_repo, user_repo, product_id, bidder_id, amount, now) }
  end

  def record_bid(bid_repo, user_repo, product_id, bidder_id, amount, now)
    bidder_name = user_repo.find_by_id(bidder_id)&.name || "Unknown"
    bid_repo.add(Basic4::Bid.new(
      id:           SecureRandom.uuid,
      product_id:   product_id,
      bidder_id:    bidder_id,
      bidder_name:  bidder_name,
      amount_cents: amount,
      created_at:   now
    ))
  end

  def coerce_int(value)
    return value if value.is_a?(Integer)
    Integer(value.to_s, exception: false)
  end
end
