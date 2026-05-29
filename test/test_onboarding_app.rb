ENV["RACK_ENV"] = "test"
ENV["MONGO_DB"] = "basic4_onboarding_test"

require "minitest/autorun"
require "rack/test"
require_relative "../app"

class TestOnboardingApp < Minitest::Test
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

  def signup!(email: "ada@example.com", password: "password1", name: "Ada")
    post_json "/api/signup", email: email, password: password, name: name
    assert_equal 201, last_response.status
    JSON.parse(last_response.body)["user"]
  end

  def stored_token(user_id)
    Basic4::DB.users.find(_id: user_id).first["email_verification"]["token"]
  end

  def test_full_onboarding_flow
    user = signup!
    assert_equal "verify_email", user["step"]
    refute user["email_verified"]

    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal "credit_scoring", body.dig("user", "step")
    assert body.dig("user", "email_verified")

    post_json "/api/onboarding/credit-score",
              income: 80_000, employment: "employed", debt: 10_000, history_years: 5
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal "done", body.dig("user", "step")
    score = body.dig("user", "credit_score", "score")
    assert_kind_of Integer, score
    assert score.between?(300, 850), "expected score in [300,850], got #{score}"
  end

  def test_signup_rejects_short_password
    post_json "/api/signup", email: "x@y.z", password: "short", name: "X"
    assert_equal 422, last_response.status
    assert_equal "password", JSON.parse(last_response.body)["field"]
  end

  def test_signup_rejects_duplicate_email
    signup!(email: "dup@example.com")
    post "/api/signout"
    post_json "/api/signup", email: "dup@example.com", password: "password1", name: "B"
    assert_equal 422, last_response.status
    assert_equal "email", JSON.parse(last_response.body)["field"]
  end

  def test_verify_email_requires_signin
    post_json "/api/onboarding/verify-email", token: "123456"
    assert_equal 401, last_response.status
  end

  def test_verify_email_rejects_wrong_token
    signup!
    post_json "/api/onboarding/verify-email", token: "000000"
    assert_equal 422, last_response.status
    assert_equal "token", JSON.parse(last_response.body)["field"]
  end

  def test_verify_email_rejects_expired_token
    user = signup!
    Basic4::DB.users.update_one(
      { _id: user["id"] },
      { "$set" => { "email_verification.expires_at" => Time.now.utc - 60 } }
    )
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    assert_equal 422, last_response.status
    assert_equal "token", JSON.parse(last_response.body)["field"]
  end

  def test_resend_token_issues_new_token
    user = signup!
    original = stored_token(user["id"])
    post_json "/api/onboarding/resend-token"
    assert_equal 200, last_response.status
    refute_equal original, stored_token(user["id"])
  end

  def test_credit_score_rejects_invalid_employment
    user = signup!
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    post_json "/api/onboarding/credit-score",
              income: 50_000, employment: "ceo", debt: 0, history_years: 1
    assert_equal 422, last_response.status
    assert_equal "employment", JSON.parse(last_response.body)["field"]
  end

  def test_credit_score_blocked_when_email_not_verified
    signup!
    post_json "/api/onboarding/credit-score",
              income: 50_000, employment: "employed", debt: 0, history_years: 1
    assert_equal 422, last_response.status
    assert_equal "step", JSON.parse(last_response.body)["field"]
  end
end
