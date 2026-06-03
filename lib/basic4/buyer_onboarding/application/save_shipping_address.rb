require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/ports/user_repository"
require_relative "../../shared/container"
require_relative "inputs"

module Basic4::BuyerOnboarding::Application::SaveShippingAddress
  module_function

  REQUIRED = %i[line1 city region postal_code country].freeze

  def call(user_id, input, container: Basic4::Container.production)
    repo, clock = container.values_at(:user_repository, :clock)

    user = repo.find_by_id(user_id)
    return Basic4::Result.failure(:user, "user not found") unless user

    validate(normalize(input))
      .bind { |address| user.save_shipping_address(address: address, at: clock.now) }
      .tap_ok { |u| repo.store(u) }
  end

  def normalize(input)
    Basic4::ShippingAddress.new(
      line1:       input.line1.to_s.strip,
      line2:       input.line2.to_s.strip,
      city:        input.city.to_s.strip,
      region:      input.region.to_s.strip,
      postal_code: input.postal_code.to_s.strip,
      country:     input.country.to_s.strip
    )
  end

  def validate(address)
    REQUIRED.each do |field|
      return Basic4::Result.failure(field, "#{field} required") if address.public_send(field).empty?
    end
    Basic4::Result.success(address)
  end
end
