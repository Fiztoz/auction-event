require_relative "../../identity"

# Outbound notification port — how the user receives codes/links.
# Required:
#   email_verification_token(email, token) -> nil
#   password_reset_token(email, token)     -> nil
module Basic4::Identity::Ports::Notifier; end
