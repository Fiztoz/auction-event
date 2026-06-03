require_relative "test_helper"
require "stringio"

class TestProductAuction < Minitest::Test
  include TestHelper

  VALID = {
    title: "Vintage desk lamp", description: "Brass, fully working",
    category: "home", starting_price_cents: 4500, duration_days: 7
  }.freeze

  def test_seller_can_list_a_product_and_see_it
    complete_seller_onboarding!

    post_json "/api/products", VALID
    assert_equal 201, last_response.status
    product = JSON.parse(last_response.body)["product"]
    refute_nil product["id"]
    assert_equal "draft", product["status"]
    assert_equal 4500, product["starting_price_cents"]

    get "/api/products/mine"
    assert_equal 200, last_response.status
    products = JSON.parse(last_response.body)["products"]
    assert_equal 1, products.length
    assert_equal "Vintage desk lamp", products.first["title"]
  end

  def test_rejects_missing_title
    complete_seller_onboarding!
    post_json "/api/products", VALID.merge(title: "")
    assert_equal 422, last_response.status
    assert_equal "title", JSON.parse(last_response.body)["field"]
  end

  def test_rejects_unknown_category
    complete_seller_onboarding!
    post_json "/api/products", VALID.merge(category: "weapons")
    assert_equal 422, last_response.status
    assert_equal "category", JSON.parse(last_response.body)["field"]
  end

  def test_rejects_out_of_range_duration
    complete_seller_onboarding!
    post_json "/api/products", VALID.merge(duration_days: 31)
    assert_equal 422, last_response.status
    assert_equal "duration_days", JSON.parse(last_response.body)["field"]
  end

  def test_requires_a_session
    post_json "/api/products", VALID
    assert_equal 401, last_response.status
  end

  def test_requires_completed_onboarding
    signup! # leaves the user at the verify_email step, not "done"
    post_json "/api/products", VALID
    assert_equal 403, last_response.status
  end

  def test_buyer_who_has_not_upgraded_cannot_sell
    user = complete_onboarding! # finished onboarding but still a buyer
    assert_equal "buyer", user["role"]
    post_json "/api/products", VALID
    assert_equal 403, last_response.status
  end

  # ── images ──────────────────────────────────────────────────────

  def test_stores_image_urls
    complete_seller_onboarding!
    urls = ["http://minio/basic4-products/a.jpg", "http://minio/basic4-products/b.jpg"]
    post_json "/api/products", VALID.merge(images: urls)
    assert_equal 201, last_response.status
    assert_equal urls, JSON.parse(last_response.body).dig("product", "images")
  end

  def test_rejects_more_than_three_images
    complete_seller_onboarding!
    post_json "/api/products", VALID.merge(images: %w[a b c d].map { |n| "http://x/#{n}.jpg" })
    assert_equal 422, last_response.status
    assert_equal "images", JSON.parse(last_response.body)["field"]
  end

  # ── editing ─────────────────────────────────────────────────────

  def test_seller_can_edit_their_auction
    complete_seller_onboarding!
    post_json "/api/products", VALID
    id = JSON.parse(last_response.body).dig("product", "id")

    put_json "/api/products/#{id}", VALID.merge(title: "Updated lamp", starting_price_cents: 9900)
    assert_equal 200, last_response.status
    product = JSON.parse(last_response.body)["product"]
    assert_equal "Updated lamp", product["title"]
    assert_equal 9900, product["starting_price_cents"]
  end

  def test_cannot_edit_another_sellers_auction
    complete_seller_onboarding!(email: "owner@example.com")
    post_json "/api/products", VALID
    id = JSON.parse(last_response.body).dig("product", "id")

    complete_seller_onboarding!(email: "intruder@example.com") # session now the other seller
    put_json "/api/products/#{id}", VALID.merge(title: "Hijacked")
    assert_equal 422, last_response.status
    assert_equal "product", JSON.parse(last_response.body)["field"]
  end

  def test_edit_requires_a_session
    complete_seller_onboarding!
    post_json "/api/products", VALID
    id = JSON.parse(last_response.body).dig("product", "id")

    post "/api/signout"
    put_json "/api/products/#{id}", VALID.merge(title: "Nope")
    assert_equal 401, last_response.status
  end

  # ── starting ────────────────────────────────────────────────────

  # Creates a draft auction as the current seller and returns its id.
  def create_draft!
    post_json "/api/products", VALID
    JSON.parse(last_response.body).dig("product", "id")
  end

  def test_seller_starts_a_draft_auction
    complete_seller_onboarding!
    id = create_draft!
    post_json "/api/products/#{id}/start"
    assert_equal 200, last_response.status
    product = JSON.parse(last_response.body)["product"]
    assert_equal "live", product["status"]
    refute_nil product["started_at"]
    refute_nil product["ends_at"]
  end

  def test_cannot_start_an_already_live_auction
    complete_seller_onboarding!
    id = create_draft!
    post_json "/api/products/#{id}/start"
    post_json "/api/products/#{id}/start"
    assert_equal 422, last_response.status
    assert_equal "status", JSON.parse(last_response.body)["field"]
  end

  def test_cannot_edit_a_live_auction
    complete_seller_onboarding!
    id = create_draft!
    post_json "/api/products/#{id}/start"
    put_json "/api/products/#{id}", VALID.merge(title: "Too late")
    assert_equal 422, last_response.status
    assert_equal "status", JSON.parse(last_response.body)["field"]
  end

  def test_cannot_start_another_sellers_auction
    complete_seller_onboarding!(email: "owner@example.com")
    id = create_draft!
    complete_seller_onboarding!(email: "intruder@example.com")
    post_json "/api/products/#{id}/start"
    assert_equal 422, last_response.status
    assert_equal "product", JSON.parse(last_response.body)["field"]
  end

  def test_start_requires_a_session
    complete_seller_onboarding!
    id = create_draft!
    post "/api/signout"
    post_json "/api/products/#{id}/start"
    assert_equal 401, last_response.status
  end

  def test_buyer_cannot_start_auctions
    complete_onboarding! # buyer
    post_json "/api/products/anything/start"
    assert_equal 403, last_response.status
  end

  # ── public catalog ──────────────────────────────────────────────

  def test_public_listing_shows_all_sellers_newest_first
    complete_seller_onboarding!(email: "alice@example.com")
    post_json "/api/products", VALID.merge(title: "Alice lamp")
    complete_seller_onboarding!(email: "bob@example.com")
    post_json "/api/products", VALID.merge(title: "Bob chair")

    post "/api/signout" # browse with no session at all
    get "/api/products"
    assert_equal 200, last_response.status
    titles = JSON.parse(last_response.body)["products"].map { |p| p["title"] }
    assert_includes titles, "Alice lamp"
    assert_includes titles, "Bob chair"
    assert_equal "Bob chair", titles.first # newest-first
  end

  def test_public_listing_needs_no_auth
    get "/api/products" # never signed in
    assert_equal 200, last_response.status
    assert_kind_of Array, JSON.parse(last_response.body)["products"]
  end

  def test_browse_page_is_served
    get "/browse"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "/js/browse.js"
  end
end

# Pure unit test for the image-upload use-case — injects a fake object storage
# via the container kwarg, so it needs neither MinIO nor MongoDB.
class TestUploadImage < Minitest::Test
  FakeStorage = Class.new do
    def self.put(key:, io:, content_type:)
      "http://fake/#{key}"
    end
  end

  def container
    { object_storage: FakeStorage }
  end

  def call(content_type:, size:)
    Basic4::ProductAuction::Application::UploadImage.call(
      "seller-1", io: StringIO.new("bytes"), content_type: content_type, size: size, container: container
    )
  end

  def test_accepts_a_jpeg_and_returns_a_url
    result = call(content_type: "image/jpeg", size: 1_000)
    assert result.success?
    assert_match %r{\Ahttp://fake/products/seller-1/.+\.jpg\z}, result.value[:url]
  end

  def test_rejects_unsupported_content_type
    result = call(content_type: "text/plain", size: 1_000)
    assert result.failure?
    assert_equal :image, result.field
  end

  def test_rejects_oversized_file
    result = call(content_type: "image/png", size: 6 * 1024 * 1024)
    assert result.failure?
    assert_equal :image, result.field
  end
end
