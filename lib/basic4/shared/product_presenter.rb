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
      status:               product.status,
      created_at:           product.created_at
    }
  end
end
