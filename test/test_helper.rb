# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require 'json'

# Set test environment before loading app
ENV['RACK_ENV'] = 'test'

# Load application
require_relative '../app'

# Include rack/test helpers in tests
module Minitest
  class Test
    include Rack::Test::Methods

    def app
      ReportingApp
    end

    def setup
      # Clean test data before each test
      clean_test_data
    end

    def teardown
      # Clean test data after each test
      clean_test_data
    end

    private

    def clean_test_data
      Database.execute("DELETE FROM report_events WHERE event_id LIKE 'test-%'")
      Database.execute("DELETE FROM report_approval_queue WHERE product_id LIKE 'test-%'")
      Database.execute("DELETE FROM report_active_auctions WHERE product_id LIKE 'test-%'")
      Database.execute("DELETE FROM report_settlements WHERE settlement_id LIKE 'test-%'")
      Database.execute("DELETE FROM report_seller_stats WHERE seller_id LIKE 'test-%'")
      Database.execute("DELETE FROM report_platform_daily WHERE report_date = CURDATE()")
    end

    def create_test_event(event_type: 'product.listed', event_id: "test-#{SecureRandom.uuid}", payload: {})
      {
        'event_id' => event_id,
        'event_type' => event_type,
        'source_service' => 'selling',
        'created_at' => Time.now.utc.iso8601,
        'payload' => payload
      }
    end
  end
end
