module Basic4
  module Identity
    module Ports
      # Random identifier + token generation port.
      #
      # Concrete adapter: lib/basic4/identity/adapters/secure_random_token_generator.rb
      #
      # Required instance methods:
      #   user_id              -> String  (a fresh user identifier)
      #   email_token          -> String  (6-digit numeric verification code)
      #   password_reset_token -> String  (long opaque reset token)
      module TokenGenerator
      end
    end
  end
end
