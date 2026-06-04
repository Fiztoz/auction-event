require_relative "shared"
require_relative "product"

module Basic4::ProductPresenter
  def self.call(product)
    {
      id:                   product.id,
      seller_id:            product.seller_id,
      title:                product.title,
      description:          product.description,
      category:             product.category,
      starting_price_cents: product.starting_price_cents,
      duration_days:        product.duration_days,
      images:               product.images,
      status:               product.status,
      started_at:           product.started_at,
      ends_at:              product.ends_at,
      ended_at:             product.ended_at,
      current_bid_cents:    product.current_bid_cents,
      bid_count:            product.bid_count,
      highest_bidder_id:    product.highest_bidder_id,
      created_at:           product.created_at,
      updated_at:           product.updated_at
    }
  end
end
