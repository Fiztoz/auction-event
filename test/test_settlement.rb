require_relative "test_helper"

class TestSettlement < Minitest::Test
  include TestHelper

  VALID = {
    title: "Vintage desk lamp", description: "Brass, fully working",
    category: "home", starting_price_cents: 4500, duration_days: 7
  }.freeze

  # Seller lists + starts an auction, a buyer wins it, and the seller stops it.
  # Leaves the session signed out of the buyer (logged back in as the seller).
  # Returns the product id. With bid: false the auction ends with no winner.
  def ended_auction_with_winner!(seller: "sue@example.com", buyer: "bob@example.com",
                                 seller_name: "Sue Seller", buyer_name: "Bob Buyer",
                                 amount: 5000, bid: true)
    complete_seller_onboarding!(email: seller, name: seller_name)
    post_json "/api/products", VALID
    id = JSON.parse(last_response.body).dig("product", "id")
    post_json "/api/products/#{id}/start"
    if bid
      complete_onboarding!(email: buyer, name: buyer_name)
      post_json "/api/products/#{id}/bid", amount_cents: amount
      post_json "/api/login", email: seller, password: "password1"
    end
    post_json "/api/products/#{id}/stop"
    id
  end

  # Drives an ended auction all the way to an open settlement (as admin). Returns
  # [product_id, settlement_id].
  def invoiced!(**opts)
    id = ended_auction_with_winner!(**opts)
    sign_in_admin!
    post_json "/api/admin/products/#{id}/settlement"
    [id, JSON.parse(last_response.body).dig("settlement", "id")]
  end

  # ── invoicing ───────────────────────────────────────────────────

  def test_admin_invoices_the_winner
    id = ended_auction_with_winner!(amount: 5000)
    sign_in_admin!
    post_json "/api/admin/products/#{id}/settlement"
    assert_equal 201, last_response.status
    s = JSON.parse(last_response.body)["settlement"]
    assert_equal "invoiced", s["status"]
    assert_equal 5000, s["amount_cents"]
    refute_nil s["buyer_id"]
    refute_nil s["invoiced_at"]
    # The buyer's shipping address is snapshotted onto the settlement.
    assert_equal "1 Market St", s.dig("shipping_address", "line1")
  end

  def test_cannot_invoice_a_live_auction
    complete_seller_onboarding!
    post_json "/api/products", VALID
    id = JSON.parse(last_response.body).dig("product", "id")
    post_json "/api/products/#{id}/start" # live, not ended
    sign_in_admin!
    post_json "/api/admin/products/#{id}/settlement"
    assert_equal 422, last_response.status
    assert_equal "status", JSON.parse(last_response.body)["field"]
  end

  def test_cannot_invoice_an_auction_with_no_winner
    id = ended_auction_with_winner!(bid: false)
    sign_in_admin!
    post_json "/api/admin/products/#{id}/settlement"
    assert_equal 422, last_response.status
    assert_equal "winner", JSON.parse(last_response.body)["field"]
  end

  def test_cannot_invoice_twice
    id, = invoiced!
    post_json "/api/admin/products/#{id}/settlement"
    assert_equal 422, last_response.status
    assert_equal "settlement", JSON.parse(last_response.body)["field"]
  end

  def test_cannot_invoice_a_missing_auction
    sign_in_admin!
    post_json "/api/admin/products/nope/settlement"
    assert_equal 422, last_response.status
    assert_equal "product", JSON.parse(last_response.body)["field"]
  end

  # ── lifecycle ───────────────────────────────────────────────────

  def test_full_settlement_lifecycle_completes_the_auction
    id, sid = invoiced!

    post_json "/api/admin/settlements/#{sid}/payment"
    assert_equal 200, last_response.status
    assert_equal "paid", JSON.parse(last_response.body).dig("settlement", "status")

    post_json "/api/admin/settlements/#{sid}/shipment"
    assert_equal "shipped", JSON.parse(last_response.body).dig("settlement", "status")

    post_json "/api/admin/settlements/#{sid}/complete"
    s = JSON.parse(last_response.body)["settlement"]
    assert_equal "completed", s["status"]
    refute_nil s["completed_at"]

    # Completing the settlement marks the underlying auction completed.
    get "/api/products/#{id}"
    assert_equal "completed", JSON.parse(last_response.body).dig("product", "status")
  end

  def test_cannot_record_shipment_before_payment
    _id, sid = invoiced!
    post_json "/api/admin/settlements/#{sid}/shipment"
    assert_equal 422, last_response.status
    assert_equal "status", JSON.parse(last_response.body)["field"]
  end

  def test_cannot_complete_before_shipment
    _id, sid = invoiced!
    post_json "/api/admin/settlements/#{sid}/payment"
    post_json "/api/admin/settlements/#{sid}/complete"
    assert_equal 422, last_response.status
    assert_equal "status", JSON.parse(last_response.body)["field"]
  end

  def test_cannot_pay_twice
    _id, sid = invoiced!
    post_json "/api/admin/settlements/#{sid}/payment"
    post_json "/api/admin/settlements/#{sid}/payment"
    assert_equal 422, last_response.status
    assert_equal "status", JSON.parse(last_response.body)["field"]
  end

  def test_advancing_a_missing_settlement_is_404ish
    sign_in_admin!
    post_json "/api/admin/settlements/nope/payment"
    assert_equal 422, last_response.status
    assert_equal "settlement", JSON.parse(last_response.body)["field"]
  end

  # ── admin party visibility (PII) ────────────────────────────────

  def test_admin_sees_seller_and_winner_identities
    id = ended_auction_with_winner!(seller_name: "Sue Seller", buyer_name: "Bob Buyer")
    sign_in_admin!
    get "/api/admin/auctions/#{id}"
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal "Sue Seller", body.dig("seller", "name")
    assert_equal "sue@example.com", body.dig("seller", "email")

    assert_equal "Bob Buyer", body.dig("winner", "name")
    assert_equal "bob@example.com", body.dig("winner", "email")
    assert_equal "1 Market St", body.dig("winner", "shipping_address", "line1")
  end

  def test_admin_detail_winner_is_null_without_bids
    id = ended_auction_with_winner!(bid: false)
    sign_in_admin!
    get "/api/admin/auctions/#{id}"
    assert_equal 200, last_response.status
    assert_nil JSON.parse(last_response.body)["winner"]
    assert_nil JSON.parse(last_response.body)["settlement"]
  end

  def test_admin_detail_includes_open_settlement
    id, sid = invoiced!
    get "/api/admin/auctions/#{id}"
    assert_equal sid, JSON.parse(last_response.body).dig("settlement", "id")
  end

  def test_admin_detail_404_for_missing_auction
    sign_in_admin!
    get "/api/admin/auctions/nope"
    assert_equal 404, last_response.status
  end

  # ── visibility of completed auctions ────────────────────────────

  def test_completed_auction_still_listed_for_admin
    _id, sid = invoiced!
    post_json "/api/admin/settlements/#{sid}/payment"
    post_json "/api/admin/settlements/#{sid}/shipment"
    post_json "/api/admin/settlements/#{sid}/complete"

    get "/api/admin/auctions"
    products = JSON.parse(last_response.body)["products"]
    assert_equal 1, products.length
    assert_equal "completed", products.first["status"]
  end

  # ── settlement queue ────────────────────────────────────────────

  def test_queue_lists_auctions_with_a_winner
    ended_auction_with_winner!
    sign_in_admin!
    get "/api/admin/settlements"
    assert_equal 200, last_response.status
    items = JSON.parse(last_response.body)["items"]
    assert_equal 1, items.length
    assert_equal "Bob Buyer", items.first.dig("winner", "name")
    assert_nil items.first["settlement"] # not invoiced yet
  end

  def test_queue_reflects_open_settlement
    id, sid = invoiced!
    get "/api/admin/settlements"
    item = JSON.parse(last_response.body)["items"].find { |i| i.dig("product", "id") == id }
    assert_equal sid, item.dig("settlement", "id")
    assert_equal "invoiced", item.dig("settlement", "status")
  end

  def test_queue_excludes_auctions_without_a_winner
    ended_auction_with_winner!(bid: false)
    sign_in_admin!
    get "/api/admin/settlements"
    assert_empty JSON.parse(last_response.body)["items"]
  end

  def test_queue_requires_admin
    ended_auction_with_winner! # leaves session as the seller
    get "/api/admin/settlements"
    assert_equal 403, last_response.status
    post "/api/signout"
    get "/api/admin/settlements"
    assert_equal 401, last_response.status
  end

  # ── auth gating ─────────────────────────────────────────────────

  def test_settlement_endpoints_require_a_session
    id = ended_auction_with_winner!
    post "/api/signout"
    post_json "/api/admin/products/#{id}/settlement"
    assert_equal 401, last_response.status
    get "/api/admin/auctions/#{id}"
    assert_equal 401, last_response.status
  end

  def test_buyer_cannot_drive_settlement
    id = ended_auction_with_winner!
    complete_onboarding!(email: "nosy@example.com") # a plain buyer
    post_json "/api/admin/products/#{id}/settlement"
    assert_equal 403, last_response.status
    get "/api/admin/auctions/#{id}"
    assert_equal 403, last_response.status
  end

  def test_seller_cannot_drive_settlement
    id = ended_auction_with_winner!
    # current session is the seller who owns the auction
    post_json "/api/admin/products/#{id}/settlement"
    assert_equal 403, last_response.status
  end
end
