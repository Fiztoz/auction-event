require_relative "../../shared/shared"
require_relative "../../shared/product"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"

module Basic4::ProductAuction::Application::BrowseProducts
  module_function

  # Public catalog read: every product that's visible to buyers (i.e., NOT
  # pending_approval or rejected). Newest-first. A read with no failure mode,
  # so it returns a plain Array<Basic4::Product>.
  def call(container: Basic4::Container.production)
    container[:product_repository].find_public
  end
end
