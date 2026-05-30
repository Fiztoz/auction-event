require "securerandom"

module Basic4
  module Identity
    module Adapters
      class SecureRandomTokenGenerator
        def user_id
          SecureRandom.uuid
        end

        def email_token
          format("%06d", SecureRandom.random_number(1_000_000))
        end

        def password_reset_token
          SecureRandom.hex(16)
        end
      end
    end
  end
end
