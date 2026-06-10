#!/usr/bin/env ruby
# frozen_string_literal: true

# Mock Bidding Service Events
# Publishes: bid.placed, auction.ended

require 'bunny'
require 'json'
require 'securerandom'

EXCHANGE = 'bidding'
RABBITMQ_URL = ENV.fetch('RABBITMQ_URL', 'amqp://guest:guest@rabbitmq:5672')

def connect
  conn = Bunny.new(RABBITMQ_URL)
  conn.start
  conn.create_channel
end

def publish_event(channel, routing_key, payload)
  exchange = channel.exchange(EXCHANGE, type: 'topic', durable: true)
  exchange.publish(
    payload.to_json,
    routing_key: routing_key,
    persistent: true
  )
  puts "📤 Published: #{routing_key}"
  puts "   Payload: #{payload.to_json}"
  puts
end

def random_uuid
  SecureRandom.uuid
end

def random_name
  ['John\'s Shop', 'Alice Crafts', 'Bob\'s Store', 'Emma\'s Bazaar', 'Charlie\'s Goods'].sample
end

def random_category
  ['electronics', 'home', 'fashion', 'toys', 'collectibles'].sample
end

# ============================================
# Event: bid.placed
# ============================================
def publish_bid_placed(channel, product_id: nil, seller_id: nil, current_bid: 1000)
  product_id ||= random_uuid
  seller_id ||= random_uuid
  new_bid = current_bid + rand(100..5000)
  
  payload = {
    event_type: 'bid.placed',
    source_service: 'bidding',
    payload: {
      product_id: product_id,
      seller_id: seller_id,
      seller_name: random_name,
      bidder_id: random_uuid,
      amount_cents: new_bid,
      bid_count: rand(1..20),
      placed_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'bid.placed', payload)
  new_bid
end

# ============================================
# Event: auction.ended
# ============================================
def publish_auction_ended(channel, product_id: nil, seller_id: nil, final_price: 5000)
  product_id ||= random_uuid
  seller_id ||= random_uuid
  
  payload = {
    event_type: 'auction.ended',
    source_service: 'bidding',
    payload: {
      product_id: product_id,
      seller_id: seller_id,
      winner_id: random_uuid,
      final_price_cents: final_price,
      bid_count: rand(1..20),
      ended_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'auction.ended', payload)
end

# ============================================
# Main
# ============================================
if __FILE__ == $PROGRAM_NAME
  puts "🚀 Mock Bidding Service"
  puts "   Exchange: #{EXCHANGE}"
  puts "   RabbitMQ: #{RABBITMQ_URL}"
  puts
  
  channel = connect
  
  puts "Publishing bidding events..."
  puts "=" * 50
  
  # Start with a bid on a random product
  current_bid = publish_bid_placed(channel)
  sleep 0.5
  
  publish_auction_ended(
    channel,
    final_price: current_bid
  )
  
  puts "=" * 50
  puts "✅ Done!"
  
  channel.connection.close
end
