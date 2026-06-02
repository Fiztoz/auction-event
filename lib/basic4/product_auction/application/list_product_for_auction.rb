require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/product"
require_relative "../../shared/ports/product_repository"
require_relative "../../shared/container"
require_relative "inputs"

module Basic4::ProductAuction::Application::ListProductForAuction
  module_function

  def call(seller_id, input, container: Basic4::Container.production)
    repo, tokens, clock = container.values_at(:product_repository, :tokens, :clock)

    i = normalize(input)
    Basic4::Product.create(
      id:                   tokens.product_id,
      seller_id:            seller_id,
      title:                i.title,
      description:          i.description,
      category:             i.category,
      starting_price_cents: i.starting_price_cents,
      duration_days:        i.duration_days,
      at:                   clock.now
    ).tap_ok { |product| repo.store(product) }
  end

  def normalize(input)
    Basic4::ProductAuction::Application::Inputs::ListProduct.new(
      title:                input.title.to_s.strip,
      description:          input.description.to_s.strip,
      category:             input.category.to_s.strip.downcase,
      starting_price_cents: coerce_int(input.starting_price_cents),
      duration_days:        coerce_int(input.duration_days)
    )
  end

  # Integer-or-nil: only coerce clean numeric values so the aggregate can reject
  # blanks/garbage with a field error rather than silently treating them as 0.
  def coerce_int(value)
    return value if value.is_a?(Integer)
    Integer(value.to_s, exception: false)
  end
end
