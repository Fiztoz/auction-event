require_relative "test_helper"

class TestProductAuction < Minitest::Test
  include TestHelper

  VALID = {
    title: "Vintage desk lamp", description: "Brass, fully working",
    category: "home", starting_price_cents: 4500, duration_days: 7
  }.freeze

  def test_seller_can_list_a_product_and_see_it
    complete_onboarding!

    post_json "/api/products", VALID
    assert_equal 201, last_response.status
    product = JSON.parse(last_response.body)["product"]
    refute_nil product["id"]
    assert_equal "open", product["status"]
    assert_equal 4500, product["starting_price_cents"]

    get "/api/products/mine"
    assert_equal 200, last_response.status
    products = JSON.parse(last_response.body)["products"]
    assert_equal 1, products.length
    assert_equal "Vintage desk lamp", products.first["title"]
  end

  def test_rejects_missing_title
    complete_onboarding!
    post_json "/api/products", VALID.merge(title: "")
    assert_equal 422, last_response.status
    assert_equal "title", JSON.parse(last_response.body)["field"]
  end

  def test_rejects_unknown_category
    complete_onboarding!
    post_json "/api/products", VALID.merge(category: "weapons")
    assert_equal 422, last_response.status
    assert_equal "category", JSON.parse(last_response.body)["field"]
  end

  def test_rejects_out_of_range_duration
    complete_onboarding!
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
end
