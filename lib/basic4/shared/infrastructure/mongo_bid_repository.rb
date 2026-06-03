require_relative "../shared"
require_relative "../db"
require_relative "../bid"
require_relative "../ports/bid_repository"

module Basic4::Infrastructure::MongoBidRepository
  def self.add(bid)
    Basic4::DB.bids.insert_one(serialize(bid))
    nil
  end

  def self.find_by_product(product_id)
    Basic4::DB.bids.find(product_id: product_id).sort(created_at: -1).map { |doc| hydrate(doc) }
  end

  def self.hydrate(doc)
    Basic4::Bid.new(
      id:           doc["_id"],
      product_id:   doc["product_id"],
      bidder_id:    doc["bidder_id"],
      bidder_name:  doc["bidder_name"],
      amount_cents: doc["amount_cents"],
      created_at:   doc["created_at"]
    )
  end

  def self.serialize(bid)
    {
      "_id"          => bid.id,
      "product_id"   => bid.product_id,
      "bidder_id"    => bid.bidder_id,
      "bidder_name"  => bid.bidder_name,
      "amount_cents" => bid.amount_cents,
      "created_at"   => bid.created_at
    }
  end
end
