module Basic4
  module Identity
    module Ports
      # Password hashing port.
      #
      # Concrete adapter: lib/basic4/identity/adapters/bcrypt_password_hasher.rb
      #
      # Required instance methods:
      #   hash(plain_password)                 -> String   (the stored hash)
      #   verify(plain_password, stored_hash)  -> Boolean
      module PasswordHasher
      end
    end
  end
end
