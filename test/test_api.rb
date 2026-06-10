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

  def test_browse_page
    get '/browse'
    assert_equal 200, last_response.status
  end

  def test_dashboard_page
    get '/dashboard'
    assert_equal 200, last_response.status
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
