module Basic4
  module Identity
    module Ports
      # Outbound notification port — how the user receives codes/links.
      #
      # The production adapter logs to stdout; a real SMTP adapter could
      # be dropped in without changing any domain code.
      #
      # Concrete adapter: lib/basic4/identity/adapters/stdout_notifier.rb
      #
      # Required instance methods:
      #   email_verification_token(email, token) -> nil
      #   password_reset_token(email, token)     -> nil
      module Notifier
      end
    end
  end
end
