ENV["RACK_ENV"] = "test"
ENV["MONGO_DB"] = "basic4_onboarding_test"

require "minitest/autorun"
require "rack/test"
require_relative "../app"

module TestHelper
  include Rack::Test::Methods

  def app
    Basic4::OnboardingApp
  end

  def setup
    Basic4::DB.users.drop
    Basic4::DB.ensure_indexes!
  rescue Mongo::Error
    skip "MongoDB not available"
  end

  def post_json(path, payload = {})
    post path, payload.to_json, "CONTENT_TYPE" => "application/json"
  end

  def patch_json(path, payload = {})
    patch path, payload.to_json, "CONTENT_TYPE" => "application/json"
  end

  def put_json(path, payload = {})
    put path, payload.to_json, "CONTENT_TYPE" => "application/json"
  end

  def signup!(email: "ada@example.com", password: "password1", name: "Ada")
    post_json "/api/signup", email: email, password: password, name: name
    JSON.parse(last_response.body)["user"]
  end

  SHIP = {
    line1: "1 Market St", city: "San Francisco", region: "CA",
    postal_code: "94105", country: "US"
  }.freeze

  # Completes buyer onboarding: signup -> verify -> shipping. Returns a buyer
  # at step "done", role "buyer".
  def complete_onboarding!(email: "ada@example.com", password: "password1", name: "Ada")
    user = signup!(email: email, password: password, name: name)
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    post_json "/api/onboarding/shipping-address", SHIP
    JSON.parse(last_response.body)["user"]
  end

  # Buyer onboarding + the "become a seller" upgrade. Returns a seller.
  def complete_seller_onboarding!(email: "ada@example.com", password: "password1", name: "Ada")
    complete_onboarding!(email: email, password: password, name: name)
    post_json "/api/onboarding/become-seller"
    post_json "/api/onboarding/credit-score",
              income: 80_000, employment: "employed", debt: 10_000, history_years: 5
    JSON.parse(last_response.body)["user"]
  end

  def stored_token(user_id)
    Basic4::DB.users.find(_id: user_id).first["email_verification"]["token"]
  end

  def stored_reset_token(user_id)
    pr = Basic4::DB.users.find(_id: user_id).first["password_reset"]
    pr && pr["token"]
  end
end
