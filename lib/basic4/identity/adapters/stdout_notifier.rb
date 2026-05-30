module Basic4
  module Identity
    module Adapters
      class StdoutNotifier
        def initialize(io: $stdout)
          @io = io
        end

        def email_verification_token(email, token)
          @io.puts "[basic4] verification token for #{email}: #{token}"
          @io.flush
        end

        def password_reset_token(email, token)
          @io.puts "[basic4] password reset token for #{email}: #{token}"
          @io.flush
        end
      end
    end
  end
end
