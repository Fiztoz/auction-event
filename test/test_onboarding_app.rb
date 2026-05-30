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

  def login!(email:, password:)
    post_json "/api/login", email: email, password: password
    JSON.parse(last_response.body)
  end

  def complete_onboarding!(email: "ada@example.com", password: "password1", name: "Ada")
    user = signup!(email: email, password: password, name: name)
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    post_json "/api/onboarding/credit-score",
              income: 80_000, employment: "employed", debt: 10_000, history_years: 5
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

  # ── login ────────────────────────────────────────────────────────

  def test_login_success_establishes_session
    signup!
    post "/api/signout"
    post_json "/api/login", email: "ada@example.com", password: "password1"
    assert_equal 200, last_response.status
    assert_equal "ada@example.com", JSON.parse(last_response.body).dig("user", "email")

    get "/api/me"
    assert_equal 200, last_response.status
  end

  def test_login_wrong_password_returns_401_generic
    signup!
    post "/api/signout"
    post_json "/api/login", email: "ada@example.com", password: "wrong-password"
    assert_equal 401, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal "credentials", body["field"]
    assert_equal "invalid email or password", body["error"]
  end

  def test_login_unknown_email_returns_401_generic
    post_json "/api/login", email: "nobody@example.com", password: "password1"
    assert_equal 401, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal "credentials", body["field"]
    assert_equal "invalid email or password", body["error"]
  end

  def test_login_preserves_onboarding_step
    signup!
    post "/api/signout"
    post_json "/api/login", email: "ada@example.com", password: "password1"
    assert_equal "verify_email", JSON.parse(last_response.body).dig("user", "step")
  end

  # ── profile update ───────────────────────────────────────────────

  def test_patch_profile_name_only
    complete_onboarding!
    patch "/api/profile", { name: "Ada Lovelace" }.to_json, "CONTENT_TYPE" => "application/json"
    assert_equal 200, last_response.status
    user = JSON.parse(last_response.body)["user"]
    assert_equal "Ada Lovelace", user["name"]
    assert_equal "done", user["step"]
    assert user["email_verified"]
  end

  def test_patch_password_requires_current_password
    complete_onboarding!
    patch "/api/profile", { new_password: "newpassword1" }.to_json, "CONTENT_TYPE" => "application/json"
    assert_equal 422, last_response.status
    assert_equal "current_password", JSON.parse(last_response.body)["field"]
  end

  def test_patch_password_rejects_wrong_current_password
    complete_onboarding!
    patch "/api/profile",
          { new_password: "newpassword1", current_password: "wrong" }.to_json,
          "CONTENT_TYPE" => "application/json"
    assert_equal 422, last_response.status
    assert_equal "current_password", JSON.parse(last_response.body)["field"]
  end

  def test_patch_password_change_allows_login_with_new_password
    complete_onboarding!
    patch "/api/profile",
          { new_password: "newpassword1", current_password: "password1" }.to_json,
          "CONTENT_TYPE" => "application/json"
    assert_equal 200, last_response.status

    post "/api/signout"
    post_json "/api/login", email: "ada@example.com", password: "newpassword1"
    assert_equal 200, last_response.status

    post "/api/signout"
    post_json "/api/login", email: "ada@example.com", password: "password1"
    assert_equal 401, last_response.status
  end

  def test_patch_email_resets_to_verify_email_and_reissues_token
    user = complete_onboarding!
    old_token = stored_token(user["id"])
    patch "/api/profile",
          { email: "ada-new@example.com", current_password: "password1" }.to_json,
          "CONTENT_TYPE" => "application/json"
    assert_equal 200, last_response.status

    body = JSON.parse(last_response.body)["user"]
    assert_equal "ada-new@example.com", body["email"]
    assert_equal "verify_email", body["step"]
    refute body["email_verified"]

    refute_equal old_token, stored_token(user["id"])
  end

  def test_patch_email_rejects_duplicate
    complete_onboarding!(email: "ada@example.com")
    post "/api/signout"
    signup!(email: "second@example.com", password: "password1", name: "Second")
    patch "/api/profile",
          { email: "ada@example.com", current_password: "password1" }.to_json,
          "CONTENT_TYPE" => "application/json"
    assert_equal 422, last_response.status
    assert_equal "email", JSON.parse(last_response.body)["field"]
  end

  def test_patch_profile_requires_signin
    patch "/api/profile", { name: "Anon" }.to_json, "CONTENT_TYPE" => "application/json"
    assert_equal 401, last_response.status
  end

  # ── password reset ───────────────────────────────────────────────

  def stored_reset_token(user_id)
    pr = Basic4::DB.users.find(_id: user_id).first["password_reset"]
    pr && pr["token"]
  end

  def test_forgot_password_issues_token_for_existing_user
    user = signup!
    post "/api/signout"
    post_json "/api/password/forgot", email: "ada@example.com"
    assert_equal 200, last_response.status
    refute_nil stored_reset_token(user["id"])
  end

  def test_forgot_password_returns_200_for_unknown_email
    post_json "/api/password/forgot", email: "ghost@example.com"
    assert_equal 200, last_response.status
    assert_equal({ "ok" => true }, JSON.parse(last_response.body))
  end

  def test_reset_password_with_valid_token_changes_password
    user = signup!
    post "/api/signout"
    post_json "/api/password/forgot", email: "ada@example.com"
    token = stored_reset_token(user["id"])

    post_json "/api/password/reset", token: token, new_password: "fresh-secret"
    assert_equal 200, last_response.status

    # token is single-use
    assert_nil stored_reset_token(user["id"])

    # new password works
    post_json "/api/login", email: "ada@example.com", password: "fresh-secret"
    assert_equal 200, last_response.status

    # old password no longer works
    post "/api/signout"
    post_json "/api/login", email: "ada@example.com", password: "password1"
    assert_equal 401, last_response.status
  end

  def test_reset_password_rejects_unknown_token
    post_json "/api/password/reset", token: "00000000000000000000000000000000", new_password: "fresh-secret"
    assert_equal 422, last_response.status
    assert_equal "token", JSON.parse(last_response.body)["field"]
  end

  def test_reset_password_rejects_expired_token
    user = signup!
    post "/api/signout"
    post_json "/api/password/forgot", email: "ada@example.com"
    token = stored_reset_token(user["id"])

    Basic4::DB.users.update_one(
      { _id: user["id"] },
      { "$set" => { "password_reset.expires_at" => Time.now.utc - 60 } }
    )

    post_json "/api/password/reset", token: token, new_password: "fresh-secret"
    assert_equal 422, last_response.status
    assert_equal "token", JSON.parse(last_response.body)["field"]
  end

  def test_reset_password_rejects_short_new_password
    user = signup!
    post "/api/signout"
    post_json "/api/password/forgot", email: "ada@example.com"
    token = stored_reset_token(user["id"])

    post_json "/api/password/reset", token: token, new_password: "short"
    assert_equal 422, last_response.status
    assert_equal "new_password", JSON.parse(last_response.body)["field"]
  end
end
