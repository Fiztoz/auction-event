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
    Basic4::DB.products.drop
    Basic4::DB.bids.drop
    Basic4::DB.settlements.drop
    Basic4::DB.notifications.drop
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
  # Records the email so `create_draft!` can sign back in after admin approval.
  def complete_seller_onboarding!(email: "ada@example.com", password: "password1", name: "Ada")
    @last_seller_email = email
    @last_seller_password = password
    complete_onboarding!(email: email, password: password, name: name)
    post_json "/api/onboarding/become-seller"
    post_json "/api/onboarding/credit-score",
              income: 80_000, employment: "employed", debt: 10_000, history_years: 5
    JSON.parse(last_response.body)["user"]
  end

  # Seeds a back-office admin straight through the container (admins are never
  # created via signup), the same way bin/create_admin does.
  def create_admin!(email: "admin@example.com", password: "password1", name: "Admin")
    c = Basic4::Container.production
    user = Basic4::User.create_admin(
      id:            c[:tokens].user_id,
      email:         email,
      name:          name,
      password_hash: c[:password_hasher].hash(password),
      at:            c[:clock].now
    )
    c[:user_repository].store(user)
    user
  end

  # Seeds an admin and signs in as them. Returns the presented user.
  def sign_in_admin!(email: "admin@example.com", password: "password1")
    create_admin!(email: email, password: password)
    post_json "/api/login", email: email, password: password
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
