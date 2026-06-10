#!/usr/bin/env ruby
# frozen_string_literal: true

# Mock Selling Service Events
# Publishes: product.listed, product.approved, product.rejected, auction.started

require 'bunny'
require 'json'
require 'securerandom'

EXCHANGE = 'selling'
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
# Event: product.listed
# ============================================
def publish_product_listed(channel)
  product_id = random_uuid
  seller_id = random_uuid
  
  payload = {
    event_type: 'product.listed',
    source_service: 'selling',
    payload: {
      product_id: product_id,
      seller_id: seller_id,
      seller_name: random_name,
      title: "Product #{rand(1000..9999)}",
      description: "A great product for auction",
      category: random_category,
      price_cents: rand(1000..50000),
      duration_days: [3, 5, 7].sample,
      status: 'pending_approval',
      created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'product.listed', payload)
  product_id
end

# ============================================
# Event: product.approved
# ============================================
def publish_product_approved(channel, product_id = nil, seller_id = nil)
  product_id ||= random_uuid
  seller_id ||= random_uuid
  
  payload = {
    event_type: 'product.approved',
    source_service: 'selling',
    payload: {
      product_id: product_id,
      seller_id: seller_id,
      seller_name: random_name,
      admin_id: random_uuid,
      approved_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'product.approved', payload)
end

# ============================================
# Event: auction.started
# ============================================
def publish_auction_started(channel)
  product_id = random_uuid
  seller_id = random_uuid
  starting_price = rand(1000..25000)
  
  payload = {
    event_type: 'auction.started',
    source_service: 'selling',
    payload: {
      product_id: product_id,
      seller_id: seller_id,
      seller_name: random_name,
      title: "Auction #{rand(1000..9999)}",
      description: "Exciting auction item",
      category: random_category,
      starting_price_cents: starting_price,
      current_bid_cents: starting_price,
      duration_days: [3, 5, 7].sample,
      status: 'live',
      started_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
      ends_at: (Time.now + rand(1..7) * 86400).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'auction.started', payload)
  { product_id: product_id, seller_id: seller_id, current_bid: starting_price }
end

# ============================================
# Event: product.rejected
# ============================================
def publish_product_rejected(channel, product_id = nil, seller_id = nil)
  product_id ||= random_uuid
  seller_id ||= random_uuid
  
  reasons = [
    'Description too vague',
    'Price too high for category',
    'Missing required images',
    'Violates listing guidelines',
    'Duplicate listing'
  ]
  
  payload = {
    event_type: 'product.rejected',
    source_service: 'selling',
    payload: {
      product_id: product_id,
      seller_id: seller_id,
      seller_name: random_name,
      admin_id: random_uuid,
      reason: reasons.sample,
      rejected_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'product.rejected', payload)
end

# ============================================
# Main
# ============================================
if __FILE__ == $PROGRAM_NAME
  puts "🚀 Mock Selling Service"
  puts "   Exchange: #{EXCHANGE}"
  puts "   RabbitMQ: #{RABBITMQ_URL}"
  puts
  
  channel = connect
  
  puts "Publishing selling events..."
  puts "=" * 50
  
  # Create a seller_id to use across events
  seller_id = random_uuid
  
  product_id = publish_product_listed(channel)
  sleep 0.5
  
  publish_product_approved(channel, product_id, seller_id)
  sleep 0.5
  
  publish_product_rejected(channel, nil, seller_id)
  sleep 0.5
  
  publish_auction_started(channel)
  
  puts "=" * 50
  puts "✅ Done!"
  
  channel.connection.close
end
