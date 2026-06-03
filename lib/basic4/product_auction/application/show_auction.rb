require_relative "../../shared/shared"
require_relative "../../shared/product"
require_relative "../../shared/bid"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/ports/bid_repository"
require_relative "../../shared/container"

module Basic4::ProductAuction::Application::ShowAuction
  module_function

  # Public read of a single auction plus its bid history (newest-first).
  # Returns { product:, bids: } or nil when the product doesn't exist.
  def call(product_id, container: Basic4::Container.production)
    product_repo, bid_repo = container.values_at(:product_repository, :bid_repository)

    product = product_repo.find_by_id(product_id)
    return nil unless product

    { product: product, bids: bid_repo.find_by_product(product_id) }
  end
end
