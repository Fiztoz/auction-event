require_relative "../shared"

# Persistence port for the Bid record.
#
# Required module methods on adapters:
#   add(bid)                  -> nil
#   find_by_product(product_id) -> Array<Basic4::Bid>  (newest-first)
module Basic4::Ports::BidRepository
end
