require_relative "test_helper"

class TestCheckExisting < Minitest::Test
  include TestHelper

  def test_unknown_email_returns_false
    post_json "/api/check-existing", email: "ghost@example.com"
    assert_equal 200, last_response.status
    assert_equal({ "exists" => false }, JSON.parse(last_response.body))
  end

  def test_known_email_returns_true
    signup!(email: "ada@example.com")
    post "/api/signout"
    post_json "/api/check-existing", email: "ada@example.com"
    assert_equal 200, last_response.status
    assert_equal({ "exists" => true }, JSON.parse(last_response.body))
  end

  def test_malformed_email_returns_422
    post_json "/api/check-existing", email: "not-an-email"
    assert_equal 422, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal "email", body["field"]
  end
end
