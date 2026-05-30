module Basic4
  module Identity
    module Adapters
      class SystemClock
        def now
          Time.now.utc
        end
      end
    end
  end
end
