require_relative "../../identity"

# Persistence port for the User aggregate.
#
# Required module methods on adapters:
#   find_by_id(id)                       -> Domain::User | nil
#   find_by_email(email)                 -> Domain::User | nil
#   find_by_password_reset_token(token)  -> Domain::User | nil
#   store(user)                          -> nil  (raises DuplicateEmail on email-uniqueness conflict)
module Basic4::Identity::Ports::UserRepository
  class DuplicateEmail < StandardError; end
end
