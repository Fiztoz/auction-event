require_relative "test_helper"

class TestVerifyToken < Minitest::Test
  include TestHelper

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

  def test_verify_email_with_correct_token_advances_step
    user = signup!
    post_json "/api/onboarding/verify-email", token: stored_token(user["id"])
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal "credit_scoring", body.dig("user", "step")
    assert body.dig("user", "email_verified")
  end

  def test_resend_token_issues_new_token
    user = signup!
    original = stored_token(user["id"])
    post_json "/api/onboarding/resend-token"
    assert_equal 200, last_response.status
    refute_equal original, stored_token(user["id"])
  end
end
