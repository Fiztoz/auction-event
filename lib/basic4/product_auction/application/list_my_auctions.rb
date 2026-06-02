require_relative "../../shared/shared"
require_relative "../../shared/product"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"

module Basic4::ProductAuction::Application::ListMyAuctions
  module_function

  # Returns a plain Array<Basic4::Product> (newest-first) for the seller — a
  # read with no failure mode, so it does not wrap in a Result.
  def call(seller_id, container: Basic4::Container.production)
    container[:product_repository].find_by_seller(seller_id)
  end
end
