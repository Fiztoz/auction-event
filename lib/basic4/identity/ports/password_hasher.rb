require_relative "../../identity"

# Password hashing port.
# Required: hash(plain) -> String;  verify(plain, stored_hash) -> Boolean
module Basic4::Identity::Ports::PasswordHasher; end
