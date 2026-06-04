require_relative "../shared"
require_relative "../db"
require_relative "../product"
require_relative "../ports/product_repository"

module Basic4::Infrastructure::MongoProductRepository
  def self.store(product)
    Basic4::DB.products.find_one_and_replace({ _id: product.id }, serialize(product), upsert: true)
    nil
  end

  def self.find_by_seller(seller_id)
    Basic4::DB.products.find(seller_id: seller_id).sort(created_at: -1).map { |doc| hydrate(doc) }
  end

  def self.find_all
    Basic4::DB.products.find.sort(created_at: -1).map { |doc| hydrate(doc) }
  end

  # Closed auctions only (status "ended"), most-recently-ended first. Backs the
  # admin back-office view, which is restricted to settled listings.
  def self.find_ended
    Basic4::DB.products.find(status: "ended").sort(ended_at: -1).map { |doc| hydrate(doc) }
  end

  def self.find_by_id(id)
    doc = Basic4::DB.products.find(_id: id).first
    doc && hydrate(doc)
  end

  def self.hydrate(doc)
    # Legacy docs were created as "open" (instantly live) before the draft
    # lifecycle existed — treat them as live and backfill a start time.
    status = doc["status"] == "open" ? "live" : doc["status"]
    started_at = doc["started_at"] || (status == "live" ? doc["created_at"] : nil)

    Basic4::Product.new(
      id:                   doc["_id"],
      seller_id:            doc["seller_id"],
      title:                doc["title"],
      description:          doc["description"],
      category:             doc["category"],
      starting_price_cents: doc["starting_price_cents"],
      duration_days:        doc["duration_days"],
      images:               doc["images"] || [],
      status:               status,
      started_at:           started_at,
      ends_at:              doc["ends_at"],
      ended_at:             doc["ended_at"],
      current_bid_cents:    doc["current_bid_cents"],
      bid_count:            doc["bid_count"] || 0,
      highest_bidder_id:    doc["highest_bidder_id"],
      created_at:           doc["created_at"],
      updated_at:           doc["updated_at"] || doc["created_at"]
    )
  end

  def self.serialize(product)
    {
      "_id"                  => product.id,
      "seller_id"            => product.seller_id,
      "title"                => product.title,
      "description"          => product.description,
      "category"             => product.category,
      "starting_price_cents" => product.starting_price_cents,
      "duration_days"        => product.duration_days,
      "images"               => product.images,
      "status"               => product.status,
      "started_at"           => product.started_at,
      "ends_at"              => product.ends_at,
      "ended_at"             => product.ended_at,
      "current_bid_cents"    => product.current_bid_cents,
      "bid_count"            => product.bid_count,
      "highest_bidder_id"    => product.highest_bidder_id,
      "created_at"           => product.created_at,
      "updated_at"           => product.updated_at
    }
  end
end
