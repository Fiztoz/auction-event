require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/container"

module Basic4::CreditScoring::Application::ListPendingSellers
  module_function

  def call(container: Basic4::Container.production)
    repo = container[:user_repository]
    repo.find_pending_sellers
  end
end
