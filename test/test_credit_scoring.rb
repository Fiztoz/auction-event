require_relative "test_helper"

class TestCreditScoring < Minitest::Test
  include TestHelper

  def test_full_onboarding_through_credit_score
    user = signup!
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    post_json "/api/onboarding/credit-score",
              income: 80_000, employment: "employed", debt: 10_000, history_years: 5
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal "done", body.dig("user", "step")
    score = body.dig("user", "credit_score", "score")
    assert_kind_of Integer, score
    assert score.between?(300, 850), "expected score in [300,850], got #{score}"
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
