require_relative "../shared"
require_relative "../db"
require_relative "../settlement"
require_relative "../user" # for Basic4::ShippingAddress on the snapshot
require_relative "../ports/settlement_repository"

module Basic4::Infrastructure::MongoSettlementRepository
  def self.store(settlement)
    Basic4::DB.settlements.find_one_and_replace({ _id: settlement.id }, serialize(settlement), upsert: true)
    nil
  end

  def self.find_by_id(id)
    doc = Basic4::DB.settlements.find(_id: id).first
    doc && hydrate(doc)
  end

  def self.find_by_product(product_id)
    doc = Basic4::DB.settlements.find(product_id: product_id).first
    doc && hydrate(doc)
  end

  def self.hydrate(doc)
    Basic4::Settlement.new(
      id:               doc["_id"],
      product_id:       doc["product_id"],
      seller_id:        doc["seller_id"],
      buyer_id:         doc["buyer_id"],
      amount_cents:     doc["amount_cents"],
      shipping_address: hydrate_sa(doc["shipping_address"]),
      status:           doc["status"],
      invoiced_at:      doc["invoiced_at"],
      paid_at:          doc["paid_at"],
      shipped_at:       doc["shipped_at"],
      completed_at:     doc["completed_at"],
      created_at:       doc["created_at"],
      updated_at:       doc["updated_at"]
    )
  end

  def self.serialize(settlement)
    {
      "_id"              => settlement.id,
      "product_id"       => settlement.product_id,
      "seller_id"        => settlement.seller_id,
      "buyer_id"         => settlement.buyer_id,
      "amount_cents"     => settlement.amount_cents,
      "shipping_address" => serialize_sa(settlement.shipping_address),
      "status"           => settlement.status,
      "invoiced_at"      => settlement.invoiced_at,
      "paid_at"          => settlement.paid_at,
      "shipped_at"       => settlement.shipped_at,
      "completed_at"     => settlement.completed_at,
      "created_at"       => settlement.created_at,
      "updated_at"       => settlement.updated_at
    }
  end

  def self.hydrate_sa(h)
    return nil unless h
    Basic4::ShippingAddress.new(
      line1: h["line1"], line2: h["line2"], city: h["city"],
      region: h["region"], postal_code: h["postal_code"], country: h["country"]
    )
  end

  def self.serialize_sa(sa)
    return nil unless sa
    {
      "line1" => sa.line1, "line2" => sa.line2, "city" => sa.city,
      "region" => sa.region, "postal_code" => sa.postal_code, "country" => sa.country
    }
  end
end
