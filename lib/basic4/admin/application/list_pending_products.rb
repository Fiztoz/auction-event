require_relative "../../shared/shared"
require_relative "../../shared/product"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"

module Basic4::Admin::Application::ListPendingProducts
  module_function

  def call(container: Basic4::Container.production)
    container[:product_repository].find_pending
  end
end
