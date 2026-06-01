require_relative "../shared"

# Persistence port for the User aggregate.
#
# Required module methods on adapters:
#   find_by_id(id)                       -> Basic4::User | nil
#   find_by_email(email)                 -> Basic4::User | nil
#   find_by_password_reset_token(token)  -> Basic4::User | nil
#   store(user)                          -> nil  (raises DuplicateEmail on email-uniqueness conflict)
module Basic4::Ports::UserRepository
  class DuplicateEmail < StandardError; end
end
