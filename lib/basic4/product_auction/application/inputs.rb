require_relative "../../shared/shared"

module Basic4::ProductAuction::Application::Inputs
  ListProduct = Data.define(:title, :description, :category, :starting_price_cents, :duration_days)
end
