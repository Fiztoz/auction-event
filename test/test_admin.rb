require_relative "test_helper"

class TestAdmin < Minitest::Test
  include TestHelper

  PRODUCT = {
    title: "Vintage desk lamp", description: "Brass, fully working",
    category: "home", starting_price_cents: 4500, duration_days: 7
  }.freeze

  # Creates a product in the given lifecycle state for the current seller
  # session and returns its id. state: :draft | :live | :ended.
  def make_auction!(state, overrides = {})
    post_json "/api/products", PRODUCT.merge(overrides)
    id = JSON.parse(last_response.body).dig("product", "id")
    if state == :live || state == :ended
      # Approve as admin before the seller can start.
      post "/api/signout"
      create_admin!(email: "admin@example.com")
      post_json "/api/login", email: "admin@example.com", password: "password1"
      post_json "/api/admin/products/#{id}/approve"
      post "/api/signout"
      seller_email = @last_seller_email || "seller@example.com"
      seller_password = @last_seller_password || "password1"
      post_json "/api/login", email: seller_email, password: seller_password
      post_json "/api/products/#{id}/start"
    end
    post_json "/api/products/#{id}/stop"  if state == :ended
    id
  end

  def test_admin_sees_only_closed_auctions
    complete_seller_onboarding!(email: "seller@example.com")
    make_auction!(:draft, title: "A draft")
    make_auction!(:live,  title: "A live one")
    ended_id = make_auction!(:ended, title: "A closed one")

    sign_in_admin!
    get "/api/admin/auctions"
    assert_equal 200, last_response.status
    products = JSON.parse(last_response.body)["products"]

    assert_equal 1, products.length
    assert_equal ended_id, products.first["id"]
    assert_equal "ended", products.first["status"]
  end

  def test_admin_lists_every_closed_auction
    complete_seller_onboarding!(email: "seller@example.com")
    first  = make_auction!(:ended, title: "Closed first")
    second = make_auction!(:ended, title: "Closed second")

    sign_in_admin!
    get "/api/admin/auctions"
    ids = JSON.parse(last_response.body)["products"].map { |p| p["id"] }
    assert_equal 2, ids.length
    assert_includes ids, first
    assert_includes ids, second
  end

  def test_admin_can_open_a_closed_auction_detail
    complete_seller_onboarding!(email: "seller@example.com")
    id = make_auction!(:ended)

    sign_in_admin!
    get "/api/products/#{id}"
    assert_equal 200, last_response.status
    assert_equal id, JSON.parse(last_response.body).dig("product", "id")
  end

  def test_anonymous_cannot_list_admin_auctions
    get "/api/admin/auctions"
    assert_equal 401, last_response.status
  end

  def test_buyer_cannot_list_admin_auctions
    complete_onboarding! # finished onboarding, still a buyer
    get "/api/admin/auctions"
    assert_equal 403, last_response.status
  end

  def test_seller_cannot_list_admin_auctions
    complete_seller_onboarding!
    get "/api/admin/auctions"
    assert_equal 403, last_response.status
  end

  def test_admin_account_is_a_signed_in_admin
    user = sign_in_admin!
    assert_equal "admin", user["role"]

    get "/api/me"
    assert_equal "admin", JSON.parse(last_response.body).dig("user", "role")
  end

  def test_admin_cannot_sell
    sign_in_admin!
    post_json "/api/products", PRODUCT
    assert_equal 403, last_response.status
  end

  def test_admin_page_is_served
    get "/admin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "/js/admin.js"
  end
end
