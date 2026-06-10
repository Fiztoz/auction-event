#!/usr/bin/env ruby
# frozen_string_literal: true

# Mock Settlement Service Events
# Publishes: settlement.created, settlement.invoiced, settlement.paid, settlement.shipped, settlement.completed

require 'bunny'
require 'json'
require 'securerandom'

EXCHANGE = 'settlement'
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
  ['John Smith', 'Alice Johnson', 'Bob Williams', 'Emma Brown', 'Charlie Davis'].sample
end

# ============================================
# Event: settlement.created
# ============================================
def publish_settlement_created(channel)
  settlement_id = random_uuid
  
  payload = {
    event_type: 'settlement.created',
    source_service: 'settlement',
    payload: {
      settlement_id: settlement_id,
      product_id: random_uuid,
      product_title: "Settled Item #{rand(1000..9999)}",
      seller_id: random_uuid,
      seller_name: random_name,
      buyer_id: random_uuid,
      buyer_name: random_name,
      amount_cents: rand(5000..100000),
      status: 'invoiced',
      created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'settlement.created', payload)
  settlement_id
end

# ============================================
# Event: settlement.invoiced
# ============================================
def publish_settlement_invoiced(channel, settlement_id = nil)
  settlement_id ||= random_uuid
  
  payload = {
    event_type: 'settlement.invoiced',
    source_service: 'settlement',
    payload: {
      settlement_id: settlement_id,
      product_id: random_uuid,
      product_title: "Invoiced Item #{rand(1000..9999)}",
      seller_id: random_uuid,
      buyer_id: random_uuid,
      amount_cents: rand(5000..100000),
      invoiced_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'settlement.invoiced', payload)
end

# ============================================
# Event: settlement.paid
# ============================================
def publish_settlement_paid(channel, settlement_id = nil)
  settlement_id ||= random_uuid
  
  payload = {
    event_type: 'settlement.paid',
    source_service: 'settlement',
    payload: {
      settlement_id: settlement_id,
      amount_cents: rand(5000..100000),
      paid_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'settlement.paid', payload)
end

# ============================================
# Event: settlement.shipped
# ============================================
def publish_settlement_shipped(channel, settlement_id = nil)
  settlement_id ||= random_uuid
  
  payload = {
    event_type: 'settlement.shipped',
    source_service: 'settlement',
    payload: {
      settlement_id: settlement_id,
      shipped_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'settlement.shipped', payload)
end

# ============================================
# Event: settlement.completed
# ============================================
def publish_settlement_completed(channel, settlement_id = nil)
  settlement_id ||= random_uuid
  
  payload = {
    event_type: 'settlement.completed',
    source_service: 'settlement',
    payload: {
      settlement_id: settlement_id,
      product_id: random_uuid,
      seller_id: random_uuid,
      seller_name: random_name,
      buyer_id: random_uuid,
      amount_cents: rand(5000..100000),
      completed_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'settlement.completed', payload)
end

# ============================================
# Main
# ============================================
if __FILE__ == $PROGRAM_NAME
  puts "🚀 Mock Settlement Service"
  puts "   Exchange: #{EXCHANGE}"
  puts "   RabbitMQ: #{RABBITMQ_URL}"
  puts
  
  channel = connect
  
  puts "Publishing settlement events..."
  puts "=" * 50
  
  settlement_id = publish_settlement_created(channel)
  sleep 0.5
  
  publish_settlement_paid(channel, settlement_id)
  sleep 0.5
  
  publish_settlement_shipped(channel, settlement_id)
  sleep 0.5
  
  publish_settlement_completed(channel, settlement_id)
  
  puts "=" * 50
  puts "✅ Done!"
  
  channel.connection.close
end
