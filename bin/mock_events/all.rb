#!/usr/bin/env ruby
# frozen_string_literal: true

# Mock All Services - Run all event mocks
# Usage: ruby bin/mock_events/all.rb

require_relative 'selling'
require_relative 'bidding'
require_relative 'settlement'
require_relative 'onboarding'

puts "🚀 Mock All Services - Publishing All Events"
puts "=" * 60
puts

channel = connect

# Selling Events
puts "📦 SELLING SERVICE EVENTS"
puts "-" * 40
product_id = publish_product_listed(channel)
sleep 0.3
publish_product_approved(channel, product_id)
sleep 0.3
publish_product_rejected(channel)
sleep 0.5

# Bidding Events
puts "🔨 BIDDING SERVICE EVENTS"
puts "-" * 40
auction = publish_auction_started(channel)
sleep 0.3
current_bid = publish_bid_placed(
  channel,
  product_id: auction[:product_id],
  seller_id: auction[:seller_id],
  current_bid: auction[:current_bid]
)
sleep 0.3
publish_auction_ended(
  channel,
  product_id: auction[:product_id],
  seller_id: auction[:seller_id],
  final_price: current_bid
)
sleep 0.5

# Settlement Events
puts "💰 SETTLEMENT SERVICE EVENTS"
puts "-" * 40
settlement_id = publish_settlement_created(channel)
sleep 0.3
publish_settlement_paid(channel, settlement_id)
sleep 0.3
publish_settlement_shipped(channel, settlement_id)
sleep 0.3
publish_settlement_completed(channel, settlement_id)
sleep 0.5

# Onboarding Events
puts "👤 ONBOARDING SERVICE EVENTS"
puts "-" * 40
3.times do
  publish_user_registered(channel)
  sleep 0.3
end

puts "=" * 60
puts "✅ All events published!"
puts

channel.connection.close
