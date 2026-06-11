# frozen_string_literal: true

require 'json'

# Thread-safe SSE (Server-Sent Events) broadcaster module.
# Maintains a set of connected client streams and broadcasts
# events to all of them in SSE format.
module SSEBroadcaster
  @clients = []
  @mutex = Mutex.new

  class << self
    # Subscribe a new client stream.
    # @param stream [Object] an object that responds to << (e.g. Sinatra stream out)
    def subscribe(stream)
      @mutex.synchronize do
        @clients << stream
      end
    end

    # Unsubscribe a client stream.
    # @param stream [Object] the stream to remove
    def unsubscribe(stream)
      @mutex.synchronize do
        @clients.delete(stream)
      end
    end

    # Broadcast an SSE event to all connected clients.
    # Dead clients (broken pipe / closed stream) are automatically removed.
    # @param event_type [String] the SSE event name
    # @param data [Hash, String] the data payload (will be JSON-serialized)
    def broadcast(event_type, data)
      payload = data.is_a?(String) ? data : data.to_json
      message = "event: #{event_type}\ndata: #{payload}\n\n"

      @mutex.synchronize do
        @clients.reject! do |stream|
          begin
            stream << message
            false # keep this client
          rescue IOError, Errno::EPIPE, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ECONNABORTED => e
            puts "   [SSE] Removing dead client: #{e.message}"
            true # remove this client
          rescue StandardError => e
            puts "   [SSE] Unexpected error removing dead client: #{e.class}: #{e.message}"
            true # remove this client
          end
        end
      end
    end

    # Return the current number of connected SSE clients.
    # @return [Integer]
    def client_count
      @mutex.synchronize do
        @clients.size
      end
    end
  end
end
