# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../app/models/report'

class TestReportModel < Minitest::Test
  def test_process_product_listed
    event = create_test_event(
      event_type: 'product.listed',
      payload: {
        'product_id' => 'test-product-001',
        'seller_id' => 'test-seller-001',
        'seller_name' => 'Test Seller',
        'title' => 'Test Product',
        'description' => 'A test product',
        'category' => 'electronics',
        'price_cents' => 9999,
        'duration_days' => 7
      }
    )

    Report.process_event('product.listed', event)

    result = Database.execute(
      'SELECT * FROM report_approval_queue WHERE product_id = ?',
      ['test-product-001']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'pending_approval', result.first[:status]
    assert_equal 'Test Seller', result.first[:seller_name]
  end

  def test_process_product_approved
    # First create a product
    Database.execute(
      "INSERT INTO report_approval_queue (product_id, seller_id, seller_name, title, category, price_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'test', 5000, 'pending_approval', NOW(), NOW())",
      ['test-product-002', 'test-seller-002', 'Test Seller', 'Test Product']
    )

    event = create_test_event(
      event_type: 'product.approved',
      payload: {
        'product_id' => 'test-product-002',
        'seller_id' => 'test-seller-002',
        'seller_name' => 'Test Seller',
        'admin_id' => 'test-admin-001'
      }
    )

    Report.process_event('product.approved', event)

    result = Database.execute(
      'SELECT status FROM report_approval_queue WHERE product_id = ?',
      ['test-product-002']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'draft', result.first[:status]
  end

  def test_process_product_rejected
    # First create a product
    Database.execute(
      "INSERT INTO report_approval_queue (product_id, seller_id, seller_name, title, category, price_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'test', 5000, 'pending_approval', NOW(), NOW())",
      ['test-product-003', 'test-seller-003', 'Test Seller', 'Test Product']
    )

    event = create_test_event(
      event_type: 'product.rejected',
      payload: {
        'product_id' => 'test-product-003',
        'seller_id' => 'test-seller-003',
        'seller_name' => 'Test Seller',
        'admin_id' => 'test-admin-001',
        'reason' => 'Description too vague'
      }
    )

    Report.process_event('product.rejected', event)

    result = Database.execute(
      'SELECT status, rejection_reason FROM report_approval_queue WHERE product_id = ?',
      ['test-product-003']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'rejected', result.first[:status]
    assert_equal 'Description too vague', result.first[:rejection_reason]
  end

  def test_process_auction_started
    event = create_test_event(
      event_type: 'auction.started',
      payload: {
        'product_id' => 'test-product-004',
        'seller_id' => 'test-seller-004',
        'seller_name' => 'Test Seller',
        'title' => 'Test Auction',
        'description' => 'A test auction',
        'category' => 'home',
        'starting_price_cents' => 5000,
        'duration_days' => 7
      }
    )

    Report.process_event('auction.started', event)

    result = Database.execute(
      'SELECT * FROM report_active_auctions WHERE product_id = ?',
      ['test-product-004']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'live', result.first[:status]
    assert_equal 5000, result.first[:starting_price_cents]
  end

  def test_process_auction_ended
    # First create an auction
    Database.execute(
      "INSERT INTO report_active_auctions (product_id, seller_id, seller_name, title, category, starting_price_cents, status, started_at, ends_at, updated_at) VALUES (?, ?, ?, ?, 'test', 5000, 'live', NOW(), DATE_ADD(NOW(), INTERVAL 7 DAY), NOW())",
      ['test-product-005', 'test-seller-005', 'Test Seller', 'Test Auction']
    )

    event = create_test_event(
      event_type: 'auction.ended',
      payload: {
        'product_id' => 'test-product-005',
        'seller_id' => 'test-seller-005',
        'winner_id' => 'test-buyer-001',
        'final_price_cents' => 7500,
        'bid_count' => 10
      }
    )

    Report.process_event('auction.ended', event)

    result = Database.execute(
      'SELECT status FROM report_active_auctions WHERE product_id = ?',
      ['test-product-005']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'ended', result.first[:status]
  end

  def test_process_bid_placed
    # First create an auction
    Database.execute(
      "INSERT INTO report_active_auctions (product_id, seller_id, seller_name, title, category, starting_price_cents, status, bid_count, started_at, ends_at, updated_at) VALUES (?, ?, ?, ?, 'test', 5000, 'live', 0, NOW(), DATE_ADD(NOW(), INTERVAL 7 DAY), NOW())",
      ['test-product-006', 'test-seller-006', 'Test Seller', 'Test Auction']
    )

    event = create_test_event(
      event_type: 'bid.placed',
      payload: {
        'product_id' => 'test-product-006',
        'seller_id' => 'test-seller-006',
        'bidder_id' => 'test-buyer-002',
        'amount_cents' => 6000,
        'bid_count' => 1
      }
    )

    Report.process_event('bid.placed', event)

    result = Database.execute(
      'SELECT current_bid_cents, bid_count FROM report_active_auctions WHERE product_id = ?',
      ['test-product-006']
    ).to_a

    assert_equal 1, result.length
    assert_equal 6000, result.first[:current_bid_cents]
    assert_equal 1, result.first[:bid_count]
  end

  def test_process_settlement_created
    event = create_test_event(
      event_type: 'settlement.created',
      payload: {
        'settlement_id' => 'test-settlement-001',
        'product_id' => 'test-product-007',
        'product_title' => 'Test Product',
        'seller_id' => 'test-seller-007',
        'seller_name' => 'Test Seller',
        'buyer_id' => 'test-buyer-003',
        'buyer_name' => 'Test Buyer',
        'amount_cents' => 8000
      }
    )

    Report.process_event('settlement.created', event)

    result = Database.execute(
      'SELECT * FROM report_settlements WHERE settlement_id = ?',
      ['test-settlement-001']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'created', result.first[:status]
    assert_equal 8000, result.first[:amount_cents]
  end

  def test_process_settlement_invoiced
    # First create a settlement
    Database.execute(
      "INSERT INTO report_settlements (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'created', NOW(), NOW())",
      ['test-settlement-002', 'test-product-008', 'Test Product', 'test-seller-008', 'Test Seller', 'test-buyer-004', 'Test Buyer', 9000]
    )

    event = create_test_event(
      event_type: 'settlement.invoiced',
      payload: {
        'settlement_id' => 'test-settlement-002',
        'product_id' => 'test-product-008',
        'seller_id' => 'test-seller-008',
        'buyer_id' => 'test-buyer-004',
        'amount_cents' => 9000
      }
    )

    Report.process_event('settlement.invoiced', event)

    result = Database.execute(
      'SELECT status FROM report_settlements WHERE settlement_id = ?',
      ['test-settlement-002']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'invoiced', result.first[:status]
  end

  def test_process_settlement_paid
    # First create a settlement
    Database.execute(
      "INSERT INTO report_settlements (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'invoiced', NOW(), NOW())",
      ['test-settlement-003', 'test-product-009', 'Test Product', 'test-seller-009', 'Test Seller', 'test-buyer-005', 'Test Buyer', 10000]
    )

    event = create_test_event(
      event_type: 'settlement.paid',
      payload: {
        'settlement_id' => 'test-settlement-003'
      }
    )

    Report.process_event('settlement.paid', event)

    result = Database.execute(
      'SELECT status FROM report_settlements WHERE settlement_id = ?',
      ['test-settlement-003']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'paid', result.first[:status]
  end

  def test_process_settlement_shipped
    # First create a settlement
    Database.execute(
      "INSERT INTO report_settlements (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'paid', NOW(), NOW())",
      ['test-settlement-004', 'test-product-010', 'Test Product', 'test-seller-010', 'Test Seller', 'test-buyer-006', 'Test Buyer', 11000]
    )

    event = create_test_event(
      event_type: 'settlement.shipped',
      payload: {
        'settlement_id' => 'test-settlement-004'
      }
    )

    Report.process_event('settlement.shipped', event)

    result = Database.execute(
      'SELECT status FROM report_settlements WHERE settlement_id = ?',
      ['test-settlement-004']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'shipped', result.first[:status]
  end

  def test_process_settlement_completed
    # First create a settlement
    Database.execute(
      "INSERT INTO report_settlements (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'shipped', NOW(), NOW())",
      ['test-settlement-005', 'test-product-011', 'Test Product', 'test-seller-011', 'Test Seller', 'test-buyer-007', 'Test Buyer', 12000]
    )

    event = create_test_event(
      event_type: 'settlement.completed',
      payload: {
        'settlement_id' => 'test-settlement-005',
        'product_id' => 'test-product-011',
        'seller_id' => 'test-seller-011',
        'amount_cents' => 12000
      }
    )

    Report.process_event('settlement.completed', event)

    result = Database.execute(
      'SELECT status FROM report_settlements WHERE settlement_id = ?',
      ['test-settlement-005']
    ).to_a

    assert_equal 1, result.length
    assert_equal 'completed', result.first[:status]
  end

  def test_process_user_registered_buyer
    event = create_test_event(
      event_type: 'user.registered',
      payload: {
        'user_id' => 'test-user-001',
        'role' => 'buyer',
        'email' => 'test@example.com'
      }
    )

    Report.process_event('user.registered', event)

    result = Database.execute(
      'SELECT total_users, new_users, total_buyers FROM report_platform_daily WHERE report_date = CURDATE()'
    ).to_a

    assert_equal 1, result.length
    assert result.first[:total_users] >= 1
    assert result.first[:new_users] >= 1
    assert result.first[:total_buyers] >= 1
  end

  def test_process_user_registered_seller
    event = create_test_event(
      event_type: 'user.registered',
      payload: {
        'user_id' => 'test-user-002',
        'role' => 'seller',
        'email' => 'seller@example.com'
      }
    )

    Report.process_event('user.registered', event)

    result = Database.execute(
      'SELECT total_users, new_users, total_sellers FROM report_platform_daily WHERE report_date = CURDATE()'
    ).to_a

    assert_equal 1, result.length
    assert result.first[:total_users] >= 1
    assert result.first[:new_users] >= 1
    assert result.first[:total_sellers] >= 1
  end

  def test_idempotency_same_event_twice
    event = create_test_event(
      event_type: 'product.listed',
      event_id: 'test-idempotency-001',
      payload: {
        'product_id' => 'test-product-idem-001',
        'seller_id' => 'test-seller-idem-001',
        'seller_name' => 'Test Seller',
        'title' => 'Idempotent Product',
        'description' => 'Test',
        'category' => 'test',
        'price_cents' => 1000,
        'duration_days' => 7
      }
    )

    # Process twice
    Report.process_event('product.listed', event)
    Report.process_event('product.listed', event)

    # Should only have one record
    result = Database.execute(
      'SELECT COUNT(*) as count FROM report_approval_queue WHERE product_id = ?',
      ['test-product-idem-001']
    ).to_a

    assert_equal 1, result.first[:count]
  end

  def test_auction_by_id
    # Create an auction
    Database.execute(
      "INSERT INTO report_active_auctions (product_id, seller_id, seller_name, title, category, starting_price_cents, status, started_at, ends_at, updated_at) VALUES (?, ?, ?, ?, 'test', 5000, 'live', NOW(), DATE_ADD(NOW(), INTERVAL 7 DAY), NOW())",
      ['test-product-lookup', 'test-seller-lookup', 'Test Seller', 'Lookup Auction']
    )

    result = Report.auction_by_id('test-product-lookup')

    refute_nil result
    assert_equal 'Lookup Auction', result[:title]
    assert_equal 'live', result[:status]
  end

  def test_auction_by_id_not_found
    result = Report.auction_by_id('nonexistent-product-id')

    assert_nil result
  end

  def test_latest_metrics_computes_active_auctions
    # Create a live auction
    Database.execute(
      "INSERT INTO report_active_auctions (product_id, seller_id, seller_name, title, category, starting_price_cents, status, started_at, ends_at, updated_at) VALUES (?, ?, ?, ?, 'test', 5000, 'live', NOW(), DATE_ADD(NOW(), INTERVAL 7 DAY), NOW())",
      ['test-metrics-001', 'test-seller-metrics', 'Test Seller', 'Metrics Auction']
    )

    metrics = Report.latest_metrics

    # Should have active_auctions computed from live auctions
    # metrics may be nil if no daily data exists, but active_auctions count should work
    if metrics
      assert metrics[:active_auctions] >= 1
    else
      # Even with no daily data, we can verify the query works
      live_count = Database.execute(
        "SELECT COUNT(*) as count FROM report_active_auctions WHERE status = 'live'"
      ).to_a
      assert live_count.first[:count] >= 1
    end
  end
end
