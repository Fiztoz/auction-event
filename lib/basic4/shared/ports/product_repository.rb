require_relative "../shared"

# Persistence port for the Product (auction listing) aggregate.
#
# Required module methods on adapters:
#   store(product)            -> nil
#   find_by_seller(seller_id) -> Array<Basic4::Product>  (newest-first)
module Basic4::Ports::ProductRepository
end
