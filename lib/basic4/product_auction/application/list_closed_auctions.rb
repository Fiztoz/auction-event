require_relative "../../shared/shared"
require_relative "../../shared/product"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"

module Basic4::ProductAuction::Application::ListClosedAuctions
  module_function

  # Admin read: every closed (ended) auction across all sellers, most-recently
  # ended first. A read with no failure mode, so it returns a plain
  # Array<Basic4::Product> — mirrors BrowseProducts but scoped to settled
  # listings, which is all the back-office admin is allowed to see.
  def call(container: Basic4::Container.production)
    container[:product_repository].find_ended
  end
end
