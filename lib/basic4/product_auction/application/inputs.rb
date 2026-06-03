require_relative "../../shared/shared"

module Basic4::ProductAuction::Application::Inputs
  ListProduct = Data.define(:title, :description, :category, :starting_price_cents, :duration_days, :images)
end

# Shared normalization for the create and update use-cases: trims text, lowers
# the category, coerces money/duration to Integer (or nil so the aggregate can
# reject garbage), and passes images through as an array.
module Basic4::ProductAuction::Application::Normalize
  module_function

  def call(input)
    Basic4::ProductAuction::Application::Inputs::ListProduct.new(
      title:                input.title.to_s.strip,
      description:          input.description.to_s.strip,
      category:             input.category.to_s.strip.downcase,
      starting_price_cents: coerce_int(input.starting_price_cents),
      duration_days:        coerce_int(input.duration_days),
      images:               Array(input.images)
    )
  end

  def coerce_int(value)
    return value if value.is_a?(Integer)
    Integer(value.to_s, exception: false)
  end
end
