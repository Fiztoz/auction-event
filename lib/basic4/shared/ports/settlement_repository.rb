require_relative "../shared"

# Persistence port for the Settlement aggregate.
#
# Required module methods on adapters:
#   store(settlement)            -> nil
#   find_by_id(id)               -> Basic4::Settlement | nil
#   find_by_product(product_id)  -> Basic4::Settlement | nil  (at most one per auction)
module Basic4::Ports::SettlementRepository
end
