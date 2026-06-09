require_relative "test_helper"

class TestNotifications < Minitest::Test
  include TestHelper

  def test_notification_create_factory
    n = Basic4::Notification.create(
      user_id:    "u1",
      type:       "product_approved",
      title:      "Hello",
      body:       "World",
      related_id: "p1",
      at:         Time.now
    )
    assert_equal "u1", n.user_id
    assert_equal "product_approved", n.type
    refute n.read
    assert_nil n.read_at
  end

  def test_mark_read_sets_fields
    n = Basic4::Notification.create(
      user_id: "u1", type: "product_approved", title: "t", body: "b",
      at: Time.now
    )
    now = Time.now
    read = n.mark_read(at: now)
    assert read.read
    assert_equal now, read.read_at
  end

  def test_mark_read_is_idempotent
    n = Basic4::Notification.create(
      user_id: "u1", type: "product_approved", title: "t", body: "b",
      at: Time.now
    )
    first = n.mark_read(at: Time.now)
    second = first.mark_read(at: Time.now + 60)
    assert_equal first, second  # unchanged
  end

  def test_unread_predicate
    n = Basic4::Notification.create(
      user_id: "u1", type: "product_approved", title: "t", body: "b",
      at: Time.now
    )
    assert n.unread?
    refute n.mark_read(at: Time.now).unread?
  end

  def test_store_persists_to_mongo
    repo = Basic4::Container.production[:notification_repository]
    n = Basic4::Notification.create(
      user_id: "u1", type: "product_approved", title: "t", body: "b",
      at: Time.now
    )
    stored = repo.store(n)
    refute_nil stored.id
    found = repo.find_by_id(stored.id)
    assert_equal stored.id, found.id
    assert_equal "t", found.title
  end

  def test_find_for_user_returns_only_user_notifications
    repo = Basic4::Container.production[:notification_repository]
    2.times { |i|
      repo.store(Basic4::Notification.create(
        user_id: "u1", type: "product_approved", title: "t#{i}", body: "b",
        at: Time.now
      ))
    }
    repo.store(Basic4::Notification.create(
      user_id: "u2", type: "product_approved", title: "other", body: "b",
      at: Time.now
    ))

    user1_notifs = repo.find_for_user("u1")
    assert_equal 2, user1_notifs.length
    assert user1_notifs.all? { |n| n.user_id == "u1" }
  end

  def test_mark_read_updates_in_storage
    repo = Basic4::Container.production[:notification_repository]
    n = Basic4::Notification.create(
      user_id: "u1", type: "product_approved", title: "t", body: "b",
      at: Time.now
    )
    stored = repo.store(n)
    now = Time.now
    result = repo.mark_read(stored.id, at: now)
    assert result.read
    assert_equal 0, repo.unread_count("u1")
  end

  def test_unread_count
    repo = Basic4::Container.production[:notification_repository]
    3.times { |i|
      repo.store(Basic4::Notification.create(
        user_id: "u1", type: "product_approved", title: "t#{i}", body: "b",
        at: Time.now
      ))
    }
    assert_equal 3, repo.unread_count("u1")
    assert_equal 0, repo.unread_count("u-other")
  end

  def test_find_all_admins_returns_admin_ids
    create_admin!(email: "admin@example.com", name: "Admin")
    create_admin!(email: "ops@example.com", name: "Ops")
    complete_onboarding! # a buyer, should NOT appear

    repo = Basic4::Container.production[:notification_repository]
    admin_ids = repo.find_all_admins
    assert_equal 2, admin_ids.length
  end

  # ── API ─────────────────────────────────────────────────────

  def test_list_notifications_requires_signin
    get "/api/notifications"
    assert_equal 401, last_response.status
  end

  def test_list_notifications_returns_current_users_only
    create_admin!(email: "admin@example.com", name: "Admin")
    complete_seller_onboarding!

    # Approve something so the seller gets a notification.
    post_json "/api/products", title: "Lamp", description: "x",
              category: "home", starting_price_cents: 1000, duration_days: 5
    product_id = JSON.parse(last_response.body)["product"]["id"]
    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{product_id}/approve"
    post "/api/signout"

    post_json "/api/login", email: "ada@example.com", password: "password1"
    get "/api/notifications"
    body = JSON.parse(last_response.body)
    assert body["notifications"].is_a?(Array)
    assert_equal 1, body["notifications"].length
    assert_equal 1, body["unread_count"]
  end

  def test_mark_notification_read
    create_admin!(email: "admin@example.com", name: "Admin")
    complete_seller_onboarding!
    post_json "/api/products", title: "Lamp", description: "x",
              category: "home", starting_price_cents: 1000, duration_days: 5
    product_id = JSON.parse(last_response.body)["product"]["id"]
    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{product_id}/approve"
    post "/api/signout"

    post_json "/api/login", email: "ada@example.com", password: "password1"
    get "/api/notifications"
    notif_id = JSON.parse(last_response.body)["notifications"].first["id"]

    patch_json "/api/notifications/#{notif_id}/read"
    assert_equal 200, last_response.status
    assert_equal true, JSON.parse(last_response.body)["notification"]["read"]
  end

  def test_cannot_mark_another_users_notification
    create_admin!(email: "admin@example.com", name: "Admin")
    complete_seller_onboarding!
    post_json "/api/products", title: "Lamp", description: "x",
              category: "home", starting_price_cents: 1000, duration_days: 5
    product_id = JSON.parse(last_response.body)["product"]["id"]
    post "/api/signout"
    sign_in_admin!(email: "admin@example.com", password: "password1")
    post_json "/api/admin/products/#{product_id}/approve"
    post "/api/signout"

    # Ada has the notification. Now sign in as a different user.
    complete_onboarding!(email: "other@example.com", name: "Other")
    get "/api/notifications"
    notif_id = JSON.parse(last_response.body)["notifications"].first["id"]

    patch_json "/api/notifications/#{notif_id}/read"
    assert_equal 422, last_response.status
  end
end
