module Basic4
  module Identity
    module Ports
      # Time port — abstracts "now" so domain logic can be tested
      # without freezing real time.
      #
      # Concrete adapter: lib/basic4/identity/adapters/system_clock.rb
      #
      # Required instance methods:
      #   now -> Time (UTC)
      module Clock
      end
    end
  end
end
