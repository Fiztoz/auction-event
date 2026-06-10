# frozen_string_literal: true

require 'sinatra/base'
require_relative '../models/report'
require_relative '../helpers/view_helpers'

class ReportsController < Sinatra::Base
  set :views, File.join(File.dirname(__FILE__), '..', 'views')
  helpers ViewHelpers

  # Browse - Public view of active auctions
  get '/browse' do
    @auctions = Report.active_auctions('live')
    @ended = Report.active_auctions('ended').first(10)
    erb :'reports/browse'
  end

  # Auction detail
  get '/browse/:id' do
    @auction = Report.auction_by_id(params[:id])
    halt 404, 'Auction not found' unless @auction
    erb :'reports/detail'
  end

  # Dashboard - Overview with charts
  get '/dashboard' do
    @metrics = Report.latest_metrics
    @overview = Report.platform_overview.first(7)
    @bid_activity = Report.bid_activity(7)
    erb :'reports/dashboard'
  end
end
