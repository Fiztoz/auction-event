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

  def self.hydrate(doc)
    Basic4::Product.new(
      id:                   doc["_id"],
      seller_id:            doc["seller_id"],
      title:                doc["title"],
      description:          doc["description"],
      category:             doc["category"],
      starting_price_cents: doc["starting_price_cents"],
      duration_days:        doc["duration_days"],
      status:               doc["status"],
      created_at:           doc["created_at"]
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
      "status"               => product.status,
      "created_at"           => product.created_at
    }
  end
end
