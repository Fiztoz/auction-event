#!/usr/bin/env ruby
# frozen_string_literal: true

# Mock Onboarding Service Events
# Publishes: user.registered

require 'bunny'
require 'json'
require 'securerandom'

EXCHANGE = 'onboarding'
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

def random_email
  "user#{rand(1000..9999)}@example.com"
end

# ============================================
# Event: user.registered
# ============================================
def publish_user_registered(channel)
  user_id = random_uuid
  role = ['buyer', 'seller'].sample
  
  payload = {
    event_type: 'user.registered',
    source_service: 'onboarding',
    payload: {
      user_id: user_id,
      role: role,
      email: random_email,
      registered_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    },
    created_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  }
  
  publish_event(channel, 'user.registered', payload)
  user_id
end

# ============================================
# Main
# ============================================
if __FILE__ == $PROGRAM_NAME
  puts "🚀 Mock Onboarding Service"
  puts "   Exchange: #{EXCHANGE}"
  puts "   RabbitMQ: #{RABBITMQ_URL}"
  puts
  
  channel = connect
  
  puts "Publishing onboarding events..."
  puts "=" * 50
  
  3.times do |i|
    puts "User #{i + 1}:"
    publish_user_registered(channel)
    sleep 0.5
  end
  
  puts "=" * 50
  puts "✅ Done!"
  
  channel.connection.close
end
