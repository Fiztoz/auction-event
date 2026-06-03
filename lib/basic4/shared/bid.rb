require_relative "shared"

module Basic4
  # A single bid in an auction's history. Bid validity (amount, timing, not your
  # own listing) is enforced by Basic4::Product#place_bid; this is the record.
  Bid = Data.define(:id, :product_id, :bidder_id, :bidder_name, :amount_cents, :created_at)
end
