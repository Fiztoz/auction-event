require_relative "shared"
require_relative "bid"

module Basic4::BidPresenter
  # Public projection of a bid. Does not expose the raw bidder_id; the viewer's
  # own bids are labelled "You" (and flagged `mine`).
  def self.call(bid, viewer_id: nil)
    mine = !viewer_id.nil? && viewer_id == bid.bidder_id
    {
      id:           bid.id,
      amount_cents: bid.amount_cents,
      bidder:       mine ? "You" : bid.bidder_name,
      mine:         mine,
      created_at:   bid.created_at
    }
  end
end
