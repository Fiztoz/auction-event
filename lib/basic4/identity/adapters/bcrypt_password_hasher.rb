require "bcrypt"

module Basic4
  module Identity
    module Adapters
      class BcryptPasswordHasher
        def hash(plain_password)
          BCrypt::Password.create(plain_password.to_s)
        end

        def verify(plain_password, stored_hash)
          return false if stored_hash.nil? || stored_hash.to_s.empty?
          BCrypt::Password.new(stored_hash) == plain_password.to_s
        end
      end
    end
  end
end
