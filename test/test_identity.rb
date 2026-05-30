require_relative "test_helper"

class TestIdentity < Minitest::Test
  include TestHelper

  # ── signup ───────────────────────────────────────────────────────

  def test_signup_lands_at_verify_email
    post_json "/api/signup", email: "ada@example.com", password: "password1", name: "Ada"
    assert_equal 201, last_response.status
    user = JSON.parse(last_response.body)["user"]
    assert_equal "verify_email", user["step"]
    refute user["email_verified"]
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
    patch_json "/api/profile", name: "Ada Lovelace"
    assert_equal 200, last_response.status
    user = JSON.parse(last_response.body)["user"]
    assert_equal "Ada Lovelace", user["name"]
    assert_equal "done", user["step"]
    assert user["email_verified"]
  end

  def test_patch_password_requires_current_password
    complete_onboarding!
    patch_json "/api/profile", new_password: "newpassword1"
    assert_equal 422, last_response.status
    assert_equal "current_password", JSON.parse(last_response.body)["field"]
  end

  def test_patch_password_rejects_wrong_current_password
    complete_onboarding!
    patch_json "/api/profile", new_password: "newpassword1", current_password: "wrong"
    assert_equal 422, last_response.status
    assert_equal "current_password", JSON.parse(last_response.body)["field"]
  end

  def test_patch_password_change_allows_login_with_new_password
    complete_onboarding!
    patch_json "/api/profile", new_password: "newpassword1", current_password: "password1"
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
    patch_json "/api/profile", email: "ada-new@example.com", current_password: "password1"
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
    patch_json "/api/profile", email: "ada@example.com", current_password: "password1"
    assert_equal 422, last_response.status
    assert_equal "email", JSON.parse(last_response.body)["field"]
  end

  def test_patch_profile_requires_signin
    patch_json "/api/profile", name: "Anon"
    assert_equal 401, last_response.status
  end

  # ── password reset ───────────────────────────────────────────────

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
    assert_nil stored_reset_token(user["id"])

    post_json "/api/login", email: "ada@example.com", password: "fresh-secret"
    assert_equal 200, last_response.status

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
