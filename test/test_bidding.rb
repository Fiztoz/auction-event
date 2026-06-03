require_relative "test_helper"

class TestBidding < Minitest::Test
  include TestHelper

  LISTING = {
    title: "Vintage desk lamp", description: "Brass, fully working",
    category: "home", starting_price_cents: 4500, duration_days: 7
  }.freeze

  # Seller lists and starts an auction; returns its id. Leaves the session as
  # the seller (caller typically onboards a separate bidder next).
  def live_auction!(seller_email: "seller@example.com")
    complete_seller_onboarding!(email: seller_email)
    post_json "/api/products", LISTING
    id = JSON.parse(last_response.body).dig("product", "id")
    post_json "/api/products/#{id}/start"
    id
  end

  def test_signed_in_user_can_place_first_bid
    id = live_auction!
    bidder = complete_onboarding!(email: "buyer@example.com") # session now the buyer
    post_json "/api/products/#{id}/bid", amount_cents: 4500
    assert_equal 200, last_response.status
    product = JSON.parse(last_response.body)["product"]
    assert_equal 4500, product["current_bid_cents"]
    assert_equal 1, product["bid_count"]
    assert_equal bidder["id"], product["highest_bidder_id"]
  end

  def test_first_bid_below_starting_price_rejected
    id = live_auction!
    complete_onboarding!(email: "buyer@example.com")
    post_json "/api/products/#{id}/bid", amount_cents: 4000
    assert_equal 422, last_response.status
    assert_equal "amount_cents", JSON.parse(last_response.body)["field"]
  end

  def test_later_bid_must_exceed_current
    id = live_auction!
    complete_onboarding!(email: "buyer@example.com")
    post_json "/api/products/#{id}/bid", amount_cents: 5000
    post_json "/api/products/#{id}/bid", amount_cents: 5000 # not higher
    assert_equal 422, last_response.status
    assert_equal "amount_cents", JSON.parse(last_response.body)["field"]

    post_json "/api/products/#{id}/bid", amount_cents: 5001
    assert_equal 200, last_response.status
    assert_equal 2, JSON.parse(last_response.body).dig("product", "bid_count")
  end

  def test_seller_cannot_bid_on_own_auction
    id = live_auction! # session is the seller
    post_json "/api/products/#{id}/bid", amount_cents: 9000
    assert_equal 422, last_response.status
    assert_equal "bidder", JSON.parse(last_response.body)["field"]
  end

  def test_cannot_bid_on_a_draft
    complete_seller_onboarding!(email: "seller@example.com")
    post_json "/api/products", LISTING # draft, never started
    id = JSON.parse(last_response.body).dig("product", "id")
    complete_onboarding!(email: "buyer@example.com")
    post_json "/api/products/#{id}/bid", amount_cents: 9000
    assert_equal 422, last_response.status
    assert_equal "status", JSON.parse(last_response.body)["field"]
  end

  def test_bid_requires_a_session
    id = live_auction!
    post "/api/signout"
    post_json "/api/products/#{id}/bid", amount_cents: 9000
    assert_equal 401, last_response.status
  end

  # ── detail + bid history ─────────────────────────────────────────

  def test_detail_lists_bids_newest_first_with_bidder_name
    id = live_auction!
    complete_onboarding!(email: "buyer@example.com", name: "Bea")
    post_json "/api/products/#{id}/bid", amount_cents: 5000
    post_json "/api/products/#{id}/bid", amount_cents: 6000

    get "/api/products/#{id}"
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal id, body.dig("product", "id")
    bids = body["bids"]
    assert_equal 2, bids.length
    assert_equal 6000, bids.first["amount_cents"] # newest-first
    assert_equal 5000, bids.last["amount_cents"]
    # viewer is the bidder -> own bids labelled "You"
    assert_equal "You", bids.first["bidder"]
    assert bids.first["mine"]
  end

  def test_detail_shows_bidder_name_to_others
    id = live_auction!
    complete_onboarding!(email: "buyer@example.com", name: "Bea")
    post_json "/api/products/#{id}/bid", amount_cents: 5000

    post "/api/signout" # anonymous viewer
    get "/api/products/#{id}"
    bid = JSON.parse(last_response.body)["bids"].first
    assert_equal "Bea", bid["bidder"]
    refute bid["mine"]
  end

  def test_detail_404_for_unknown_id
    get "/api/products/does-not-exist"
    assert_equal 404, last_response.status
  end

  def test_products_mine_still_routes_to_seller_list
    # The :id detail route must not swallow /api/products/mine.
    get "/api/products/mine"
    assert_equal 401, last_response.status # require_seller!, not a 404 from ShowAuction
  end
end

# Pure aggregate rules that are awkward to reach over HTTP (e.g. an expired
# auction, since the minimum duration is a full day).
class TestBiddingRules < Minitest::Test
  def live_auction
    t = Time.now
    Basic4::Product.create(
      id: "p1", seller_id: "seller", title: "t", description: "d", category: "home",
      starting_price_cents: 5000, duration_days: 7, images: [], at: t
    ).value.start(at: t).value
  end

  def test_rejects_bids_after_ends_at
    auction = live_auction
    expired = auction.with(ends_at: Time.now - 60)
    result = expired.place_bid(bidder_id: "b", amount_cents: 9000, now: Time.now)
    assert result.failure?
    assert_equal :status, result.field
  end

  def test_records_highest_bidder
    result = live_auction.place_bid(bidder_id: "b", amount_cents: 5000, now: Time.now)
    assert result.success?
    assert_equal "b", result.value.highest_bidder_id
    assert_equal 1, result.value.bid_count
  end
end
