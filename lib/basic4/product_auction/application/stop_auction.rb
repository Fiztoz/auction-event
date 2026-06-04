require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/product"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"

module Basic4::ProductAuction::Application::StopAuction
  module_function

  def call(seller_id, product_id, container: Basic4::Container.production)
    repo, clock = container.values_at(:product_repository, :clock)

    product = repo.find_by_id(product_id)
    # Collapse "not found" and "not yours" so ownership can't be probed.
    return Basic4::Result.failure(:product, "listing not found") unless product && product.seller_id == seller_id

    product.stop(at: clock.now).tap_ok { |stopped| repo.store(stopped) }
  end
end
