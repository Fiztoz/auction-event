require_relative "shared"
require_relative "result"

module Basic4
  Product = Data.define(
    :id, :seller_id, :title, :description, :category,
    :starting_price_cents, :duration_days, :status, :created_at
  )
end

# Reopen Basic4::Product to attach constants and the factory directly to the
# class — same reasoning as Basic4::User: constants defined inside a
# `Data.define do ... end` block leak to the lexical scope, not the class.
class Basic4::Product
  CATEGORIES      = %w[electronics collectibles fashion home toys other].freeze
  DURATION_DAYS   = (1..30)
  MIN_PRICE_CENTS = 1
  MAX_TITLE       = 120

  # Builds a new auction listing, validating its fields. Returns a
  # Basic4::Result wrapping the Product (Success) or a field error (Failure).
  def self.create(id:, seller_id:, title:, description:, category:, starting_price_cents:, duration_days:, at:)
    title       = title.to_s.strip
    description = description.to_s.strip
    category    = category.to_s.strip.downcase

    return Basic4::Result.failure(:title, "title required") if title.empty?
    return Basic4::Result.failure(:title, "title must be #{MAX_TITLE} chars or fewer") if title.length > MAX_TITLE
    return Basic4::Result.failure(:description, "description required") if description.empty?
    return Basic4::Result.failure(:category, "invalid category") unless CATEGORIES.include?(category)

    unless starting_price_cents.is_a?(Integer) && starting_price_cents >= MIN_PRICE_CENTS
      return Basic4::Result.failure(:starting_price_cents, "starting price must be a positive amount")
    end

    unless duration_days.is_a?(Integer) && DURATION_DAYS.cover?(duration_days)
      return Basic4::Result.failure(:duration_days, "duration must be between #{DURATION_DAYS.min} and #{DURATION_DAYS.max} days")
    end

    Basic4::Result.success(new(
      id:                   id,
      seller_id:            seller_id,
      title:                title,
      description:          description,
      category:             category,
      starting_price_cents: starting_price_cents,
      duration_days:        duration_days,
      status:               "open",
      created_at:           at
    ))
  end
end
