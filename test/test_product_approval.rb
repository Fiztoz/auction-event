require_relative "test_helper"

# Tests for the seller product approval workflow:
#   1. Domain rules: Product state transitions through pending_approval/draft/rejected
#   2. Application: ListProductForAuction fans out to admins; ApproveProduct /
#      RejectProduct notify the seller
#   3. API endpoints: gated by role, correct status codes
class TestProductApproval < Minitest::Test
  include TestHelper

  VALID = {
    title: "Vintage desk lamp", description: "Brass, fully working",
    category: "home", starting_price_cents: 4500, duration_days: 7
  }.freeze

  # ── Domain rules ─────────────────────────────────────────────

  def test_product_creation_starts_in_pending_approval
    result = Basic4::Product.create(
      id: "p1", seller_id: "s1", title: "Lamp", description: "Desc",
      category: "home", starting_price_cents: 1000, duration_days: 5,
      images: [], at: Time.now
    )
    assert result.success?
    assert_equal "pending_approval", result.value.status
    assert_nil result.value.approved_at
    assert_nil result.value.rejection_reason
  end

  def test_approve_transitions_pending_approval_to_draft
    product = create_pending
    result = product.approve(at: Time.now)
    assert result.success?
    assert_equal "draft", result.value.status
    refute_nil result.value.approved_at
    assert_nil result.value.rejection_reason
  end

  def test_reject_requires_a_reason
    product = create_pending
    result = product.reject(reason: "  ", at: Time.now)
    assert result.failure?
    assert_equal :reason, result.field
  end

  def test_reject_transitions_with_reason
    product = create_pending
    result = product.reject(reason: "Need more photos", at: Time.now)
    assert result.success?
    assert_equal "rejected", result.value.status
    assert_equal "Need more photos", result.value.rejection_reason
  end

  def test_approve_fails_on_non_pending_product
    product = create_pending.approve(at: Time.now).value  # now draft
    result = product.approve(at: Time.now)
    assert result.failure?
    assert_equal :status, result.field
  end

  def test_update_details_allowed_on_pending
    product = create_pending
    result = product.update_details(
      title: "New", description: "Desc2", category: "fashion",
      starting_price_cents: 2000, duration_days: 3, images: [],
      at: Time.now
    )
    assert result.success?
    assert_equal "pending_approval", result.value.status
  end

  def test_update_details_on_rejected_resubmits
    product = create_pending.reject(reason: "x", at: Time.now).value
    result = product.update_details(
      title: "Fixed", description: "Desc2", category: "home",
      starting_price_cents: 2000, duration_days: 5, images: [],
      at: Time.now
    )
    assert result.success?
    assert_equal "pending_approval", result.value.status
    assert_nil result.value.rejection_reason
  end

  def test_update_details_blocked_on_live
    product = create_pending.approve(at: Time.now).value.start(at: Time.now).value
    result = product.update_details(
      title: "Too late", description: "x", category: "home",
      starting_price_cents: 1000, duration_days: 5, images: [],
      at: Time.now
    )
    assert result.failure?
    assert_equal :status, result.field
  end

  # ── Application: list product notifies admins ───────────────

  def test_listing_a_product_creates_admin_notifications
    complete_seller_onboarding!
    create_admin!(email: "admin@example.com")
    create_admin!(email: "ops@example.com", name: "Ops")

    post_json "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post "/api/signout"

    # Re-sign as the seller.
    post_json "/api/login", email: "ada@example.com", password: "password1"
    post_json "/api/products", VALID

    # Inspect the notifications collection directly.
    notifs = Basic4::DB.notifications.find.to_a
    assert_equal 2, notifs.length, "every admin should get one notification"
    assert notifs.all? { |n| n["type"] == "product_pending_approval" }
    assert notifs.all? { |n| n["related_id"] }, "should reference the new product"
  end

  # ── API: admin approval ──────────────────────────────────────

  def test_seller_cannot_start_a_pending_auction
    complete_seller_onboarding!
    post_json "/api/products", VALID
    product_id = JSON.parse(last_response.body)["product"]["id"]

    # Without approval: start fails.
    post_json "/api/products/#{product_id}/start"
    assert_equal 422, last_response.status
    assert_equal "status", JSON.parse(last_response.body)["field"]
  end

  def test_admin_can_approve_and_seller_can_then_start
    complete_seller_onboarding!
    post_json "/api/products", VALID
    product_id = JSON.parse(last_response.body)["product"]["id"]

    # Switch to admin.
    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{product_id}/approve"
    assert_equal 200, last_response.status
    assert_equal "draft", JSON.parse(last_response.body)["product"]["status"]
    refute_nil JSON.parse(last_response.body)["product"]["approved_at"]

    # Back to seller.
    post "/api/signout"
    post_json "/api/login", email: "ada@example.com", password: "password1"
    post_json "/api/products/#{product_id}/start"
    assert_equal 200, last_response.status
    assert_equal "live", JSON.parse(last_response.body)["product"]["status"]
  end

  def test_approve_sends_notification_to_seller
    seller_id = complete_seller_onboarding!["id"]
    post_json "/api/products", VALID
    product_id = JSON.parse(last_response.body)["product"]["id"]

    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{product_id}/approve"
    assert_equal 200, last_response.status

    notifs = Basic4::DB.notifications.find(user_id: seller_id).to_a
    assert_equal 1, notifs.length
    assert_equal "product_approved", notifs.first["type"]
  end

  def test_admin_can_reject_with_reason
    seller_id = complete_seller_onboarding!["id"]
    post_json "/api/products", VALID
    product_id = JSON.parse(last_response.body)["product"]["id"]

    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{product_id}/reject", reason: "Photos too blurry"
    assert_equal 200, last_response.status
    assert_equal "rejected", JSON.parse(last_response.body)["product"]["status"]
    assert_equal "Photos too blurry", JSON.parse(last_response.body)["product"]["rejection_reason"]

    notifs = Basic4::DB.notifications.find(user_id: seller_id).to_a
    assert_equal 1, notifs.length
    assert_equal "product_rejected", notifs.first["type"]
    assert_includes notifs.first["body"], "Photos too blurry"
  end

  def test_admin_can_reject_missing_reason
    complete_seller_onboarding!
    post_json "/api/products", VALID
    product_id = JSON.parse(last_response.body)["product"]["id"]

    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{product_id}/reject", reason: ""
    assert_equal 422, last_response.status
    assert_equal "reason", JSON.parse(last_response.body)["field"]
  end

  def test_pending_products_endpoint_lists_only_pending
    complete_seller_onboarding!
    # Create two products, approve one.
    post_json "/api/products", VALID
    p1 = JSON.parse(last_response.body)["product"]["id"]
    post_json "/api/products", VALID.merge(title: "Second")
    p2 = JSON.parse(last_response.body)["product"]["id"]

    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{p1}/approve"
    get "/api/admin/pending-products"
    assert_equal 200, last_response.status
    products = JSON.parse(last_response.body)["products"]
    assert_equal 1, products.length
    assert_equal p2, products.first["id"]
  end

  def test_pending_endpoint_requires_admin
    complete_seller_onboarding!
    get "/api/admin/pending-products"
    assert_equal 403, last_response.status
  end

  def test_approve_requires_admin
    complete_seller_onboarding!
    post_json "/api/products", VALID
    product_id = JSON.parse(last_response.body)["product"]["id"]

    # No admin role.
    post_json "/api/admin/products/#{product_id}/approve"
    assert_equal 403, last_response.status
  end

  # ── Public browse hides pending and rejected ─────────────────

  def test_public_browse_does_not_show_pending_products
    complete_seller_onboarding!
    post_json "/api/products", VALID
    post "/api/signout"

    get "/api/products"
    products = JSON.parse(last_response.body)["products"]
    assert_empty products
  end

  def test_public_browse_shows_approved_draft
    complete_seller_onboarding!
    post_json "/api/products", VALID
    product_id = JSON.parse(last_response.body)["product"]["id"]

    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{product_id}/approve"
    post "/api/signout"

    get "/api/products"
    products = JSON.parse(last_response.body)["products"]
    assert_equal 1, products.length
  end

  private

  def create_pending
    result = Basic4::Product.create(
      id: SecureRandom.uuid, seller_id: "s1", title: "T", description: "D",
      category: "home", starting_price_cents: 1000, duration_days: 5,
      images: [], at: Time.now
    )
    result.value
  end
end
