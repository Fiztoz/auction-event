# frozen_string_literal: true

require_relative 'test_helper'

class TestApi < Minitest::Test
  def test_health_check_returns_response
    get '/api/health'
    # Health check may return 200 or 503 depending on RabbitMQ connection
    assert [200, 503].include?(last_response.status)

    json = JSON.parse(last_response.body)
    assert json.key?('status')
    assert json.key?('database')
    assert json.key?('rabbitmq')
    assert json.key?('service')
    assert_equal 'reporting', json['service']
  end

  def test_health_check_reports_database_status
    get '/api/health'

    json = JSON.parse(last_response.body)
    # Database should be up since we're running tests
    assert_equal 'up', json['database']
  end

  def test_overview_endpoint
    get '/api/reports/overview'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('overview')
  end

  def test_approval_queue_endpoint
    get '/api/reports/approval-queue'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('products')
    assert_kind_of Array, json['products']
  end

  def test_approval_queue_with_status_filter
    get '/api/reports/approval-queue?status=pending_approval'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('products')
  end

  def test_settlements_endpoint
    get '/api/reports/settlements'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('settlements')
    assert_kind_of Array, json['settlements']
  end

  def test_active_auctions_endpoint
    get '/api/reports/active-auctions'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('auctions')
    assert_kind_of Array, json['auctions']
  end

  def test_sellers_endpoint
    get '/api/reports/sellers'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('sellers')
    assert_kind_of Array, json['sellers']
  end

  def test_bid_activity_endpoint
    get '/api/reports/bid-activity'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('bidActivity')
    assert_kind_of Array, json['bidActivity']
  end

  def test_bid_activity_with_days_filter
    get '/api/reports/bid-activity?days=14'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('bidActivity')
  end

  # ============================================
  # Seller Dashboard Tests
  # ============================================

  def test_my_listings_page
    get '/admin/my-listings'
    assert_equal 200, last_response.status
    assert last_response.body.include?('My Listings')
  end

  def test_my_listings_page_with_seller_id
    # Create a test listing first
    Database.execute(
      "INSERT INTO report_approval_queue (product_id, seller_id, seller_name, title, description, category, price_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
      ['test-api-listing-001', 'test-api-seller-001', 'API Test Seller', 'API Test Product', 'Test description', 'electronics', 5000, 'pending_approval']
    )

    get '/admin/my-listings?seller_id=test-api-seller-001'
    assert_equal 200, last_response.status
    assert last_response.body.include?('API Test Product')
  end

  def test_my_revenue_page
    get '/admin/my-revenue'
    assert_equal 200, last_response.status
    assert last_response.body.include?('My Revenue')
  end

  def test_my_revenue_page_with_seller_id
    # Create test seller stats
    Database.execute(
      "INSERT INTO report_seller_stats (seller_id, seller_name, period_date, products_listed, products_approved, revenue_cents) VALUES (?, ?, CURDATE(), ?, ?, ?)",
      ['test-api-seller-rev', 'API Revenue Seller', 10, 8, 50000]
    )

    get '/admin/my-revenue?seller_id=test-api-seller-rev'
    assert_equal 200, last_response.status
    assert last_response.body.include?('API Revenue Seller')
  end

  def test_my_listings_api_requires_seller_id
    get '/api/reports/my-listings'
    assert_equal 400, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('error')
  end

  def test_my_listings_api
    # Create a test listing
    Database.execute(
      "INSERT INTO report_approval_queue (product_id, seller_id, seller_name, title, description, category, price_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
      ['test-api-listing-api', 'test-api-seller-api', 'API Seller', 'API Product', 'Desc', 'home', 7500, 'pending_approval']
    )

    get '/api/reports/my-listings?seller_id=test-api-seller-api'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('listings')
    assert_kind_of Array, json['listings']
    assert_equal 1, json['listings'].length
    assert_equal 'API Product', json['listings'].first['title']
  end

  def test_my_revenue_api_requires_seller_id
    get '/api/reports/my-revenue'
    assert_equal 400, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('error')
  end

  def test_my_revenue_api
    # Create test seller stats
    Database.execute(
      "INSERT INTO report_seller_stats (seller_id, seller_name, period_date, products_listed, products_approved, revenue_cents) VALUES (?, ?, CURDATE(), ?, ?, ?)",
      ['test-api-seller-rev-api', 'API Revenue', 15, 12, 75000]
    )

    get '/api/reports/my-revenue?seller_id=test-api-seller-rev-api'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('revenue')
    assert_equal 'API Revenue', json['revenue']['seller_name']
    assert_equal 75000, json['revenue']['total_revenue_cents'].to_i
  end

  # ============================================
  # Buyer Dashboard Tests
  # ============================================

  def test_my_bids_page
    get '/admin/my-bids'
    assert_equal 200, last_response.status
    assert last_response.body.include?('My Bids')
  end

  def test_my_bids_page_with_buyer_id
    # Create a test settlement for buyer
    Database.execute(
      "INSERT INTO report_settlements (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
      ['test-api-settle-bid', 'test-prod-bid', 'Bid Product', 'seller-bid', 'Bid Seller', 'test-api-buyer-bid', 'Bid Buyer', 10000, 'paid']
    )

    get '/admin/my-bids?buyer_id=test-api-buyer-bid'
    assert_equal 200, last_response.status
    assert last_response.body.include?('Bid Product')
  end

  def test_my_won_page
    get '/admin/my-won'
    assert_equal 200, last_response.status
    assert last_response.body.include?('My Won Auctions')
  end

  def test_my_won_page_with_buyer_id
    # Create a completed settlement
    Database.execute(
      "INSERT INTO report_settlements (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'completed', NOW(), NOW())",
      ['test-api-settle-won', 'test-prod-won', 'Won Product', 'seller-won', 'Won Seller', 'test-api-buyer-won', 'Won Buyer', 20000]
    )

    get '/admin/my-won?buyer_id=test-api-buyer-won'
    assert_equal 200, last_response.status
    assert last_response.body.include?('Won Product')
  end

  def test_my_bids_api_requires_buyer_id
    get '/api/reports/my-bids'
    assert_equal 400, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('error')
  end

  def test_my_bids_api
    # Create a test settlement for buyer
    Database.execute(
      "INSERT INTO report_settlements (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
      ['test-api-settle-bids-api', 'test-prod-bids-api', 'Bids API Product', 'seller-bids-api', 'Bids API Seller', 'test-api-buyer-bids-api', 'Bids API Buyer', 15000, 'shipped']
    )

    get '/api/reports/my-bids?buyer_id=test-api-buyer-bids-api'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('bids')
    assert_kind_of Array, json['bids']
    assert_equal 1, json['bids'].length
    assert_equal 'Bids API Product', json['bids'].first['product_title']
  end

  def test_my_won_api_requires_buyer_id
    get '/api/reports/my-won'
    assert_equal 400, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('error')
  end

  def test_my_won_api
    # Create a completed settlement
    Database.execute(
      "INSERT INTO report_settlements (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'completed', NOW(), NOW())",
      ['test-api-settle-won-api', 'test-prod-won-api', 'Won API Product', 'seller-won-api', 'Won API Seller', 'test-api-buyer-won-api', 'Won API Buyer', 25000]
    )

    get '/api/reports/my-won?buyer_id=test-api-buyer-won-api'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('won')
    assert_kind_of Array, json['won']
    assert_equal 1, json['won'].length
    assert_equal 'Won API Product', json['won'].first['product_title']
  end

  def test_my_listings_api_empty_result
    get '/api/reports/my-listings?seller_id=nonexistent-seller'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('listings')
    assert_equal 0, json['listings'].length
  end

  def test_my_bids_api_empty_result
    get '/api/reports/my-bids?buyer_id=nonexistent-buyer'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('bids')
    assert_equal 0, json['bids'].length
  end

  def test_my_won_api_empty_result
    get '/api/reports/my-won?buyer_id=nonexistent-buyer'
    assert_equal 200, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('won')
    assert_equal 0, json['won'].length
  end

  def test_admin_dashboard
    get '/admin'
    assert_equal 200, last_response.status
    assert last_response.body.include?('Platform Overview')
  end

  def test_approval_page
    get '/admin/approval'
    assert_equal 200, last_response.status
    assert last_response.body.include?('Approval Queue')
  end

  def test_settlements_page
    get '/admin/settlements'
    assert_equal 200, last_response.status
    assert last_response.body.include?('Settlement Pipeline')
  end

  def test_auctions_page
    get '/admin/auctions'
    assert_equal 200, last_response.status
    assert last_response.body.include?('Active Auctions')
  end

  def test_sellers_page
    get '/admin/sellers'
    assert_equal 200, last_response.status
    assert last_response.body.include?('Seller Leaderboard')
  end

  def test_root_redirects_to_admin
    get '/'
    assert_equal 302, last_response.status
    assert last_response.headers['Location'].end_with?('/admin')
  end

  def test_not_found_returns_json
    get '/nonexistent-path'
    assert_equal 404, last_response.status

    json = JSON.parse(last_response.body)
    assert json.key?('error')
  end
end
