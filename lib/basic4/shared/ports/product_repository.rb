require_relative "../shared"

# Persistence port for the Product (auction listing) aggregate.
#
# Required module methods on adapters:
#   store(product)            -> nil
#   find_by_seller(seller_id) -> Array<Basic4::Product>  (newest-first)
#   find_all                  -> Array<Basic4::Product>  (newest-first)
#   find_closed               -> Array<Basic4::Product>  (ended/completed, most-recently-ended first)
#   find_by_id(id)            -> Basic4::Product | nil
module Basic4::Ports::ProductRepository
end
