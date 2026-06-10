# frozen_string_literal: true

require 'bunny'
require 'json'

module RabbitMQ
  @connection = nil
  @channel = nil

  # Exchange names - one per publisher service
  EXCHANGES = {
    selling: 'selling',
    bidding: 'bidding',
    settlement: 'settlement',
    onboarding: 'onboarding'
  }.freeze

  # Queue name - consumer service name
  QUEUE = 'reporting'

  # Event routing keys by exchange
  EVENTS_BY_EXCHANGE = {
    'selling' => %w[product.listed product.approved product.rejected auction.started],
    'bidding' => %w[bid.placed auction.ended],
    'settlement' => %w[settlement.created settlement.invoiced settlement.paid settlement.shipped settlement.completed],
    'onboarding' => %w[user.registered]
  }.freeze

  # All event types
  EVENT_TYPES = EVENTS_BY_EXCHANGE.values.flatten.freeze

  def self.connect
    return true if @connection&.connected?

    host = ENV.fetch('RABBITMQ_HOST', 'localhost')
    port = ENV.fetch('RABBITMQ_PORT', '5672')
    user = ENV.fetch('RABBITMQ_USER', 'guest')
    password = ENV.fetch('RABBITMQ_PASSWORD', 'guest')

    puts "🐰 Connecting to RabbitMQ at #{host}:#{port}..."

    @connection = Bunny.new(
      host: host,
      port: port,
      user: user,
      password: password,
      automatic_recovery: true
    )

    @connection.start
    @channel = @connection.create_channel

    # Declare queue
    @channel.queue_declare(QUEUE, durable: true)

    # Declare exchanges and bind queue
    EXCHANGES.each do |service, exchange_name|
      @channel.exchange_declare(exchange_name, 'topic', durable: true)
      
      # Bind queue to exchange for all events from this service
      EVENTS_BY_EXCHANGE[exchange_name].each do |routing_key|
        @channel.queue_bind(QUEUE, exchange_name, routing_key: routing_key)
        puts "   📎 Bound: #{exchange_name} → #{QUEUE} (#{routing_key})"
      end
    end

    puts '✅ RabbitMQ connected'
    true
  rescue StandardError => e
    puts "⚠️  RabbitMQ connection failed: #{e.message}"
    puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
    puts '   Running without RabbitMQ - using seed data only'
    false
  end

  def self.consume(&block)
    return unless @connection&.connected?

    queue = @channel.queue(QUEUE, durable: true)
    queue.subscribe(manual_ack: true) do |delivery_info, _properties, payload|
      begin
        event_type = delivery_info.routing_key
        event_data = JSON.parse(payload)
        block.call(event_type, event_data)
        @channel.ack(delivery_info.delivery_tag)
      rescue StandardError => e
        puts "Error processing message: #{e.message}"
        puts "   Payload: #{payload[0..200]}"
        # Drop the message instead of requeueing to prevent infinite redelivery
        @channel.nack(delivery_info.delivery_tag, false, false)
      end
    end
  end

  def self.publish(service, routing_key, data)
    return unless @connection&.connected?

    exchange_name = EXCHANGES[service.to_sym]
    unless exchange_name
      puts "⚠️  Unknown service: #{service}"
      return
    end

    exchange = @channel.exchange(exchange_name)
    exchange.publish(
      data.to_json,
      routing_key: routing_key,
      persistent: true
    )
    puts "📤 Published: #{exchange_name} → #{routing_key}"
  end

  def self.disconnect
    @connection&.close
    @connection = nil
    @channel = nil
    puts 'RabbitMQ disconnected'
  end

  def self.connected?
    @connection&.connected? || false
  end
end
