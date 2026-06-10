# frozen_string_literal: true

require 'json'
require_relative '../../config/database'

# Report Model - READ-ONLY
# This service only reads data. Actions (approve, reject, payment, etc.)
# are handled by other microservices via events.

module Report
  # ============================================
  # READ METHODS
  # ============================================

  # Platform Overview
  def self.platform_overview
    Database.execute(
      'SELECT * FROM report_platform_daily ORDER BY report_date DESC LIMIT 30'
    ).to_a
  end

  def self.latest_metrics
    metrics = Database.execute(
      'SELECT * FROM report_platform_daily ORDER BY report_date DESC LIMIT 1'
    ).first
    
    # Compute active_auctions from live auctions instead of daily counter
    if metrics
      live_count = Database.execute(
        "SELECT COUNT(*) as count FROM report_active_auctions WHERE status = 'live'"
      ).first
      metrics['active_auctions'] = live_count['count'] if live_count
    end
    
    metrics
  end

  # Approval Queue
  def self.approval_queue(status = 'pending_approval')
    Database.execute(
      'SELECT * FROM report_approval_queue WHERE status = ? ORDER BY created_at ASC',
      [status]
    ).to_a
  end

  # Settlements
  def self.settlements(status = nil)
    sql = 'SELECT * FROM report_settlements'
    params = []
    if status
      sql += ' WHERE status = ?'
      params << status
    end
    sql += ' ORDER BY created_at DESC'
    Database.execute(sql, params).to_a
  end

  # Active Auctions
  def self.active_auctions(status = nil)
    sql = 'SELECT * FROM report_active_auctions'
    params = []
    if status
      sql += ' WHERE status = ?'
      params << status
    end
    sql += ' ORDER BY started_at DESC'
    Database.execute(sql, params).to_a
  end

  # Seller Stats
  def self.top_sellers(limit = 10)
    Database.execute(
      <<~SQL,
        SELECT seller_id, seller_name,
               SUM(products_listed) as total_listed,
               SUM(products_approved) as total_approved,
               SUM(revenue_cents) as total_revenue,
               SUM(bids_received) as total_bids
        FROM report_seller_stats
        GROUP BY seller_id, seller_name
        ORDER BY total_revenue DESC
        LIMIT ?
      SQL
      [limit]
    ).to_a
  end

  # Auction by ID
  def self.auction_by_id(product_id)
    Database.execute(
      'SELECT * FROM report_active_auctions WHERE product_id = ?',
      [product_id]
    ).first
  end

  # Bid Activity
  def self.bid_activity(days = 7)
    Database.execute(
      <<~SQL,
        SELECT period_date, SUM(total_bids) as total_bids,
               SUM(unique_bidders) as unique_bidders,
               AVG(avg_bid_cents) as avg_bid_cents
        FROM report_bid_activity
        WHERE period_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        GROUP BY period_date
        ORDER BY period_date ASC
      SQL
      [days]
    ).to_a
  end

  # ============================================
  # SELLER DASHBOARD
  # ============================================

  # My Listings (Seller) - Get products listed by a seller
  def self.my_listings(seller_id)
    Database.execute(
      'SELECT * FROM report_approval_queue WHERE seller_id = ? ORDER BY created_at DESC',
      [seller_id]
    ).to_a
  end

  # My Revenue (Seller) - Get revenue stats for a seller
  def self.my_revenue(seller_id)
    row = Database.execute(
      <<~SQL,
        SELECT seller_id, seller_name,
               COALESCE(SUM(products_listed), 0) as total_listed,
               COALESCE(SUM(products_approved), 0) as total_approved,
               COALESCE(SUM(products_rejected), 0) as total_rejected,
               COALESCE(SUM(auctions_started), 0) as total_auctions_started,
               COALESCE(SUM(auctions_ended), 0) as total_auctions_ended,
               COALESCE(SUM(revenue_cents), 0) as total_revenue_cents,
               COALESCE(SUM(bids_received), 0) as total_bids_received
        FROM report_seller_stats
        WHERE seller_id = ?
        GROUP BY seller_id, seller_name
      SQL
      [seller_id]
    ).first
    return nil unless row

    # Convert BigDecimal values to integers for consistent JSON output
    row.transform_values { |v| v.is_a?(BigDecimal) ? v.to_i : v }
  end

  # ============================================
  # BUYER DASHBOARD
  # ============================================

  # My Bids (Buyer) - Get settlements/auctions where buyer participated
  def self.my_bids(buyer_id)
    Database.execute(
      'SELECT * FROM report_settlements WHERE buyer_id = ? ORDER BY created_at DESC',
      [buyer_id]
    ).to_a
  end

  # My Won (Buyer) - Get completed auction wins for buyer
  def self.my_won(buyer_id)
    Database.execute(
      "SELECT * FROM report_settlements WHERE buyer_id = ? AND status = 'completed' ORDER BY created_at DESC",
      [buyer_id]
    ).to_a
  end

  # ============================================
  # EVENT PROCESSING (Write via events only)
  # ============================================

  # Allowed fields for metric updates (SQL injection prevention)
  ALLOWED_DAILY_FIELDS = %w[
    total_auctions_created active_auctions total_bids
    total_revenue_cents settlements_completed total_users
    new_users total_sellers total_buyers
  ].freeze

  ALLOWED_SELLER_FIELDS = %w[
    products_approved products_rejected auctions_started
    auctions_ended bids_received revenue_cents
  ].freeze

  def self.process_event(event_type, event_data)
    event_id = event_data['event_id'] || event_data['id']
    
    # Idempotency check - skip if event already processed
    if event_id
      # Check if event already exists
      existing = Database.execute(
        'SELECT id FROM report_events WHERE event_id = ?',
        [event_id]
      )
      return if existing.length > 0
      
      # Insert new event
      Database.execute(
        'INSERT IGNORE INTO report_events (event_id, event_type, source_service, payload, created_at) VALUES (?, ?, ?, ?, NOW())',
        [event_id, event_type, event_data['source_service'], event_data.to_json]
      )
    end

    data = event_data['payload'] || event_data['data'] || event_data

    case event_type
    when 'product.listed'
      handle_product_listed(data)
    when 'product.approved'
      handle_product_approved(data)
    when 'product.rejected'
      handle_product_rejected(data)
    when 'auction.started'
      handle_auction_started(data)
    when 'auction.ended'
      handle_auction_ended(data)
    when 'bid.placed'
      handle_bid_placed(data)
    when 'settlement.created'
      handle_settlement_created(data, 'created')
    when 'settlement.invoiced'
      handle_settlement_created(data, 'invoiced')
    when 'settlement.paid'
      handle_settlement_paid(data)
    when 'settlement.shipped'
      handle_settlement_shipped(data)
    when 'settlement.completed'
      handle_settlement_completed(data)
    when 'user.registered'
      handle_user_registered(data)
    end
  end

  class << self
    private

    def handle_product_listed(data)
      Database.execute(
        <<~SQL,
          INSERT INTO report_approval_queue 
          (product_id, seller_id, seller_name, title, description, category, price_cents, duration_days, status, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending_approval', NOW(), NOW())
          ON DUPLICATE KEY UPDATE updated_at = NOW()
        SQL
        [data['product_id'], data['seller_id'], data['seller_name'],
         data['title'], data['description'], data['category'],
         data['price_cents'], data['duration_days'] || 7]
      )
      update_daily_metric('total_auctions_created', 1)
    end

    def handle_product_approved(data)
      Database.execute(
        "UPDATE report_approval_queue SET status = 'draft', updated_at = NOW() WHERE product_id = ?",
        [data['product_id']]
      )
      update_seller_stat(data['seller_id'], data['seller_name'], 'products_approved', 1)
    end

    def handle_product_rejected(data)
      Database.execute(
        "UPDATE report_approval_queue SET status = 'rejected', rejection_reason = ?, updated_at = NOW() WHERE product_id = ?",
        [data['reason'], data['product_id']]
      )
      update_seller_stat(data['seller_id'], data['seller_name'], 'products_rejected', 1)
    end

    def handle_auction_started(data)
      Database.execute(
        <<~SQL,
          INSERT INTO report_active_auctions 
          (product_id, seller_id, seller_name, title, description, category, starting_price_cents, status, started_at, ends_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, 'live', NOW(), DATE_ADD(NOW(), INTERVAL ? DAY), NOW())
          ON DUPLICATE KEY UPDATE status = 'live', started_at = NOW(), updated_at = NOW()
        SQL
        [data['product_id'], data['seller_id'], data['seller_name'],
         data['title'], data['description'], data['category'],
         data['starting_price_cents'], data['duration_days'] || 7]
      )
      # active_auctions is computed at read time from live auctions
      update_seller_stat(data['seller_id'], data['seller_name'], 'auctions_started', 1)
    end

    def handle_auction_ended(data)
      Database.execute(
        "UPDATE report_active_auctions SET status = 'ended', updated_at = NOW() WHERE product_id = ?",
        [data['product_id']]
      )
      # active_auctions is computed at read time from live auctions
      update_seller_stat(data['seller_id'], data['seller_name'], 'auctions_ended', 1)
    end

    def handle_bid_placed(data)
      Database.execute(
        <<~SQL,
          UPDATE report_active_auctions 
          SET current_bid_cents = ?, bid_count = bid_count + 1, updated_at = NOW() 
          WHERE product_id = ?
        SQL
        [data['amount_cents'], data['product_id']]
      )
      update_daily_metric('total_bids', 1)
      update_seller_stat(data['seller_id'], data['seller_name'], 'bids_received', 1)
    end

    def handle_settlement_created(data, status = 'invoiced')
      Database.execute(
        <<~SQL,
          INSERT INTO report_settlements 
          (settlement_id, product_id, product_title, seller_id, seller_name, buyer_id, buyer_name, amount_cents, status, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
          ON DUPLICATE KEY UPDATE status = ?, updated_at = NOW()
        SQL
        [data['settlement_id'], data['product_id'], data['product_title'],
         data['seller_id'], data['seller_name'], data['buyer_id'],
         data['buyer_name'], data['amount_cents'], status, status]
      )
    end

    def handle_settlement_paid(data)
      Database.execute(
        "UPDATE report_settlements SET status = 'paid', updated_at = NOW() WHERE settlement_id = ?",
        [data['settlement_id']]
      )
    end

    def handle_settlement_shipped(data)
      Database.execute(
        "UPDATE report_settlements SET status = 'shipped', updated_at = NOW() WHERE settlement_id = ?",
        [data['settlement_id']]
      )
    end

    def handle_settlement_completed(data)
      Database.execute(
        "UPDATE report_settlements SET status = 'completed', updated_at = NOW() WHERE settlement_id = ?",
        [data['settlement_id']]
      )
      update_daily_metric('settlements_completed', 1)
      update_daily_metric('total_revenue_cents', data['amount_cents'] || 0)
      update_seller_stat(data['seller_id'], data['seller_name'], 'revenue_cents', data['amount_cents'] || 0)
    end

    def handle_user_registered(data)
      update_daily_metric('total_users', 1)
      update_daily_metric('new_users', 1)
      if data['role'] == 'seller'
        update_daily_metric('total_sellers', 1)
      else
        update_daily_metric('total_buyers', 1)
      end
    end

    def update_daily_metric(field, increment)
      raise "Invalid daily field: #{field}" unless ALLOWED_DAILY_FIELDS.include?(field)
      
      Database.execute(
        "INSERT INTO report_platform_daily (report_date, #{field}, updated_at)
         VALUES (CURDATE(), ?, NOW())
         ON DUPLICATE KEY UPDATE #{field} = #{field} + ?, updated_at = NOW()",
        [increment, increment]
      )
    end

    def update_seller_stat(seller_id, seller_name, field, increment)
      raise "Invalid seller field: #{field}" unless ALLOWED_SELLER_FIELDS.include?(field)
      
      Database.execute(
        "INSERT INTO report_seller_stats (seller_id, seller_name, period_date, #{field})
         VALUES (?, ?, CURDATE(), ?)
         ON DUPLICATE KEY UPDATE #{field} = #{field} + ?",
        [seller_id, seller_name, increment, increment]
      )
    end
  end
end
