require_relative "shared"
require_relative "settlement"

module Basic4::SettlementPresenter
  def self.call(settlement)
    {
      id:           settlement.id,
      product_id:   settlement.product_id,
      seller_id:    settlement.seller_id,
      buyer_id:     settlement.buyer_id,
      amount_cents: settlement.amount_cents,
      status:       settlement.status,
      shipping_address: settlement.shipping_address && {
        line1:       settlement.shipping_address.line1,
        line2:       settlement.shipping_address.line2,
        city:        settlement.shipping_address.city,
        region:      settlement.shipping_address.region,
        postal_code: settlement.shipping_address.postal_code,
        country:     settlement.shipping_address.country
      },
      invoiced_at:  settlement.invoiced_at,
      paid_at:      settlement.paid_at,
      shipped_at:   settlement.shipped_at,
      completed_at: settlement.completed_at,
      created_at:   settlement.created_at,
      updated_at:   settlement.updated_at
    }
  end

  # A counterparty's contact details for the admin back-office view: real name,
  # email, and (for the winner) shipping address. Used to fulfil the order.
  def self.party(user)
    return nil unless user
    {
      id:    user.id,
      name:  user.name,
      email: user.email,
      shipping_address: user.shipping_address && {
        line1:       user.shipping_address.line1,
        line2:       user.shipping_address.line2,
        city:        user.shipping_address.city,
        region:      user.shipping_address.region,
        postal_code: user.shipping_address.postal_code,
        country:     user.shipping_address.country
      }
    }
  end
end
