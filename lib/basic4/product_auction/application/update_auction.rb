require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/product"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"
require_relative "inputs"

module Basic4::ProductAuction::Application::UpdateAuction
  module_function

  def call(seller_id, product_id, input, container: Basic4::Container.production)
    repo, clock = container.values_at(:product_repository, :clock)

    product = repo.find_by_id(product_id)
    # Collapse "not found" and "not yours" into one response so ownership of a
    # listing can't be probed.
    return Basic4::Result.failure(:product, "listing not found") unless product && product.seller_id == seller_id

    i = Basic4::ProductAuction::Application::Normalize.call(input)
    product.update_details(
      title:                i.title,
      description:          i.description,
      category:             i.category,
      starting_price_cents: i.starting_price_cents,
      duration_days:        i.duration_days,
      images:               i.images,
      at:                   clock.now
    ).tap_ok { |updated| repo.store(updated) }
  end
end
