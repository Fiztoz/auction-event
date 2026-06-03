require_relative "../../shared/shared"

module Basic4::BuyerOnboarding::Application::Inputs
  ShippingAddress = Data.define(:line1, :line2, :city, :region, :postal_code, :country)
end
