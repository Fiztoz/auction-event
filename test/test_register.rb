require_relative "test_helper"

class TestRegister < Minitest::Test
  include TestHelper

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
end
