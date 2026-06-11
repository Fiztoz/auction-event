# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/reloader' if ENV['RACK_ENV'] == 'development'
require 'json'
require 'mysql2'
require 'bunny'
require 'dotenv/load'

# Load application files
require_relative 'config/database'
require_relative 'config/rabbitmq'
require_relative 'app/models/report'
require_relative 'app/services/sse_broadcaster'
require_relative 'app/controllers/admin_controller'
require_relative 'app/controllers/reports_controller'

class ReportingApp < Sinatra::Base
  configure do
    set :public_folder, File.join(root, 'public')
    set :views, File.join(root, 'app', 'views')
    set :erb, layout: :layout
  end

  configure :development do
    register Sinatra::Reloader
  end

  before do
    # Try to ensure database connection, but don't fail
    begin
      @db = Database.client
    rescue StandardError => e
      @db = nil
    end
  end

  # Mount controllers
  use AdminController
  use ReportsController

  # Root redirect
  get '/' do
    redirect '/admin'
  end

  # Health check
  get '/api/health' do
    content_type :json
    begin
      db_ok = Database.ping
    rescue StandardError
      db_ok = false
    end
    rabbitmq_ok = RabbitMQ.connected?
    json_response = {
      status: (db_ok && rabbitmq_ok) ? 'ok' : 'degraded',
      database: db_ok ? 'up' : 'down',
      rabbitmq: rabbitmq_ok ? 'up' : 'down',
      service: 'reporting',
      timestamp: Time.now.iso8601
    }
    status((db_ok && rabbitmq_ok) ? 200 : 503)
    json_response.to_json
  end

  not_found do
    content_type :json
    { error: 'Not found' }.to_json
  end

  error do
    content_type :json
    { error: 'Internal server error' }.to_json
  end

  helpers do
    def format_currency(cents)
      "$#{'%.2f' % (cents.to_f / 100)}"
    end

    def format_date(date_str)
      return '' unless date_str
      Time.parse(date_str.to_s).strftime('%b %d, %Y')
    end

    def time_ago(date_str)
      return '' unless date_str
      diff = Time.now - Time.parse(date_str.to_s)
      case diff
      when 0..60 then 'just now'
      when 61..3600 then "#{(diff / 60).to_i}m ago"
      when 3601..86400 then "#{(diff / 3600).to_i}h ago"
      else "#{(diff / 86400).to_i}d ago"
      end
    end

    def status_badge_class(status)
      case status
      when 'pending_approval' then 'badge-warning'
      when 'draft', 'approved' then 'badge-success'
      when 'rejected' then 'badge-danger'
      when 'live' then 'badge-info'
      when 'ended' then 'badge-secondary'
      when 'completed' then 'badge-primary'
      when 'invoiced' then 'badge-warning'
      when 'paid' then 'badge-info'
      when 'shipped' then 'badge-success'
      else 'badge-secondary'
      end
    end
  end
end

# ============================================
# RabbitMQ Consumer Background Thread
# ============================================

Thread.new do
  sleep 5 # Wait for app to start
  
  max_retries = 10
  retry_delay = 2
  
  max_retries.times do |attempt|
    puts "🐰 Starting RabbitMQ consumer (attempt #{attempt + 1}/#{max_retries})..."
    
    begin
      if RabbitMQ.connect
        puts '✅ RabbitMQ consumer connected'
        
        RabbitMQ.consume do |event_type, event_data|
          puts "📨 Received event: #{event_type}"
          
          begin
            Report.process_event(event_type, event_data)
            SSEBroadcaster.broadcast(event_type, {
              event_type: event_type,
              timestamp: Time.now.iso8601,
              data: event_data
            })
            puts "   ✅ Processed: #{event_type}"
          rescue StandardError => e
            puts "   ❌ Error processing #{event_type}: #{e.message}"
          end
        end
        
        puts '🎧 Listening for events...'
        break # Exit retry loop on success
      else
        puts "⚠️  RabbitMQ not available (attempt #{attempt + 1}/#{max_retries})"
      end
    rescue StandardError => e
      puts "⚠️  RabbitMQ connection error: #{e.message} (attempt #{attempt + 1}/#{max_retries})"
    end
    
    # Exponential backoff with cap
    delay = [retry_delay * (2 ** attempt), 60].min
    puts "   Retrying in #{delay} seconds..."
    sleep delay
  end
  
  puts "🏁 RabbitMQ consumer thread exiting (connected = #{RabbitMQ.connected?})"
end
