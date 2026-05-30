require_relative "test_helper"

class TestOnboarding < Minitest::Test
  include TestHelper

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
