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
end
