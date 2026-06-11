# frozen_string_literal: true

require 'sinatra/base'
require_relative '../models/report'
require_relative '../helpers/view_helpers'

class AdminController < Sinatra::Base
  set :views, File.join(File.dirname(__FILE__), '..', 'views')
  helpers ViewHelpers

  # ============================================
  # READ-ONLY VIEW ROUTES
  # ============================================

  # Admin Dashboard
  get '/admin' do
    @metrics = Report.latest_metrics
    @pending_count = (Report.approval_queue('pending_approval') || []).length
    @settlements = (Report.settlements || []).select { |s| s[:status] != 'completed' }.length
    erb :'admin/index'
  end

  # Approval Queue
  get '/admin/approval' do
    @products = Report.approval_queue('pending_approval')
    @rejected = Report.approval_queue('rejected')
    erb :'admin/approval'
  end

  # Settlements
  get '/admin/settlements' do
    @settlements = Report.settlements || []
    erb :'admin/settlements'
  end

  # Active Auctions
  get '/admin/auctions' do
    @auctions = Report.active_auctions
    erb :'admin/auctions'
  end

  # Sellers
  get '/admin/sellers' do
    @sellers = Report.top_sellers
    erb :'admin/sellers'
  end

  # ============================================
  # READ-ONLY JSON API ENDPOINTS
  # ============================================

  # API: Platform Overview
  get '/api/reports/overview' do
    content_type :json
    { overview: Report.platform_overview }.to_json
  end

  # API: Approval Queue
  get '/api/reports/approval-queue' do
    content_type :json
    status_filter = params[:status] || 'pending_approval'
    { products: Report.approval_queue(status_filter) }.to_json
  end

  # API: Settlements
  get '/api/reports/settlements' do
    content_type :json
    { settlements: Report.settlements(params[:status]) }.to_json
  end

  # API: Active Auctions
  get '/api/reports/active-auctions' do
    content_type :json
    { auctions: Report.active_auctions(params[:status]) }.to_json
  end

  # API: Seller Stats
  get '/api/reports/sellers' do
    content_type :json
    { sellers: Report.top_sellers }.to_json
  end

  # API: Bid Activity
  get '/api/reports/bid-activity' do
    content_type :json
    days = (params[:days] || 7).to_i
    { bidActivity: Report.bid_activity(days) }.to_json
  end

  # ============================================
  # SELLER DASHBOARD (Phase 4)
  # ============================================

  # My Listings - Seller's products
  get '/admin/my-listings' do
    @seller_id = params[:seller_id]
    @listings = @seller_id ? Report.my_listings(@seller_id) : []
    erb :'admin/my_listings'
  end

  # My Revenue - Seller's revenue stats
  get '/admin/my-revenue' do
    @seller_id = params[:seller_id]
    @revenue = @seller_id ? Report.my_revenue(@seller_id) : nil
    erb :'admin/my_revenue'
  end

  # ============================================
  # BUYER DASHBOARD (Phase 4)
  # ============================================

  # My Bids - Buyer's bid history
  get '/admin/my-bids' do
    @buyer_id = params[:buyer_id]
    @bids = @buyer_id ? Report.my_bids(@buyer_id) : []
    erb :'admin/my_bids'
  end

  # My Won - Buyer's won auctions
  get '/admin/my-won' do
    @buyer_id = params[:buyer_id]
    @won = @buyer_id ? Report.my_won(@buyer_id) : []
    erb :'admin/my_won'
  end

  # ============================================
  # SELLER JSON API ENDPOINTS
  # ============================================

  # API: My Listings
  get '/api/reports/my-listings' do
    content_type :json
    seller_id = params[:seller_id]
    halt 400, { error: 'seller_id is required' }.to_json unless seller_id
    { listings: Report.my_listings(seller_id) }.to_json
  end

  # API: My Revenue
  get '/api/reports/my-revenue' do
    content_type :json
    seller_id = params[:seller_id]
    halt 400, { error: 'seller_id is required' }.to_json unless seller_id
    { revenue: Report.my_revenue(seller_id) }.to_json
  end

  # ============================================
  # BUYER JSON API ENDPOINTS
  # ============================================

  # API: My Bids
  get '/api/reports/my-bids' do
    content_type :json
    buyer_id = params[:buyer_id]
    halt 400, { error: 'buyer_id is required' }.to_json unless buyer_id
    { bids: Report.my_bids(buyer_id) }.to_json
  end

  # API: My Won
  get '/api/reports/my-won' do
    content_type :json
    buyer_id = params[:buyer_id]
    halt 400, { error: 'buyer_id is required' }.to_json unless buyer_id
    { won: Report.my_won(buyer_id) }.to_json
  end

  # ============================================
  # SSE STREAM ENDPOINT
  # ============================================

  # SSE Stream for real-time dashboard updates
  get '/api/events/stream' do
    content_type 'text/event-stream'
    cache_control 'no-cache'
    headers 'Connection' => 'keep-alive'
    response.headers['X-Accel-Buffering'] = 'no'

    stream do |out|
      SSEBroadcaster.subscribe(out)

      # Send initial connection event
      out << "event: connected\ndata: {\"status\":\"connected\",\"timestamp\":\"#{Time.now.iso8601}\"}\n\n"

      # Keep connection alive with heartbeat every 30 seconds
      begin
        loop do
          sleep 30
          out << ": heartbeat\n\n"
        end
      rescue IOError, Errno::EPIPE
        # Client disconnected
      ensure
        SSEBroadcaster.unsubscribe(out)
      end
    end
  end

  # SSE health check
  get '/api/events/health' do
    content_type :json
    { sse_clients: SSEBroadcaster.client_count, status: 'ok' }.to_json
  end
end
