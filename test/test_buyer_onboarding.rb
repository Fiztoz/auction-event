require_relative "test_helper"

class TestBuyerOnboarding < Minitest::Test
  include TestHelper

  def test_verify_email_advances_to_shipping_address
    user = signup!
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    assert_equal "shipping_address", JSON.parse(last_response.body).dig("user", "step")
  end

  def test_shipping_address_completes_buyer_onboarding
    user = signup!
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    post_json "/api/onboarding/shipping-address", SHIP
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)["user"]
    assert_equal "done", body["step"]
    assert_equal "buyer", body["role"]
    assert_equal "San Francisco", body.dig("shipping_address", "city")
  end

  def test_shipping_address_requires_each_field
    user = signup!
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    post_json "/api/onboarding/shipping-address", SHIP.merge(city: "")
    assert_equal 422, last_response.status
    assert_equal "city", JSON.parse(last_response.body)["field"]
  end

  def test_shipping_address_requires_a_session
    post_json "/api/onboarding/shipping-address", SHIP
    assert_equal 401, last_response.status
  end

  def test_become_seller_moves_done_buyer_to_credit_scoring
    complete_onboarding! # buyer, done
    post_json "/api/onboarding/become-seller"
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)["user"]
    assert_equal "credit_scoring", body["step"]
    assert_equal "buyer", body["role"] # not a seller until credit scoring completes
  end

  def test_become_seller_rejected_before_onboarding_done
    user = signup!
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    post_json "/api/onboarding/become-seller" # still at shipping_address
    assert_equal 422, last_response.status
    assert_equal "step", JSON.parse(last_response.body)["field"]
  end
end
