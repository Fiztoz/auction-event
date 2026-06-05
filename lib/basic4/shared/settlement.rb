require_relative "shared"
require_relative "result"

module Basic4
  # A settlement is the post-auction order between the winning buyer and the
  # seller. The back-office admin drives it to completion (escrow model). It
  # snapshots the order-critical facts — the won amount and the buyer's shipping
  # address — at invoice time, so later profile edits can't mutate a placed order
  # (same rationale as Basic4::Bid snapshotting bidder_name).
  Settlement = Data.define(
    :id, :product_id, :seller_id, :buyer_id, :amount_cents,
    :shipping_address, :status,
    :invoiced_at, :paid_at, :shipped_at, :completed_at,
    :created_at, :updated_at
  )
end

# Reopen Basic4::Settlement to attach constants and behavior directly to the
# class — same reasoning as Basic4::User/Product. The aggregate class also doubles
# as the bounded-context namespace: its use cases live under
# Basic4::Settlement::Application::* (declared here rather than in shared.rb,
# because the name is owned by this Data class, not a plain module).
class Basic4::Settlement
  module Application
    module Inputs; end
  end

  # invoiced -> paid -> shipped -> completed. The completing transition also
  # records the fund transfer to the seller (no separate state); it is the point
  # at which the auction itself is marked completed.
  STATUSES = %w[invoiced paid shipped completed].freeze

  # Opens a settlement for the confirmed winner of an ended auction. Cross-
  # aggregate guards (auction ended? has a winner? not already settled?) live in
  # InvoiceWinner; this factory just builds a valid invoiced settlement. amount
  # and seller come from the won product; the address is a snapshot of the
  # buyer's shipping address.
  def self.open(id:, product:, buyer:, at:)
    new(
      id:               id,
      product_id:       product.id,
      seller_id:        product.seller_id,
      buyer_id:         buyer.id,
      amount_cents:     product.current_bid_cents,
      shipping_address: buyer.shipping_address,
      status:           "invoiced",
      invoiced_at:      at,
      paid_at:          nil,
      shipped_at:       nil,
      completed_at:     nil,
      created_at:       at,
      updated_at:       at
    )
  end

  # Buyer payment received (simulated): invoiced -> paid. The status guard makes
  # a repeated call a no-op-with-error rather than overwriting.
  def record_payment(at:)
    return Basic4::Result.failure(:status, "settlement is not awaiting payment") unless status == "invoiced"
    Basic4::Result.success(with(status: "paid", paid_at: at, updated_at: at))
  end

  # Seller shipped the item: paid -> shipped.
  def record_shipment(at:)
    return Basic4::Result.failure(:status, "settlement has not been paid") unless status == "paid"
    Basic4::Result.success(with(status: "shipped", shipped_at: at, updated_at: at))
  end

  # Funds released to the seller and the order is closed: shipped -> completed.
  def complete(at:)
    return Basic4::Result.failure(:status, "settlement has not been shipped") unless status == "shipped"
    Basic4::Result.success(with(status: "completed", completed_at: at, updated_at: at))
  end
end
