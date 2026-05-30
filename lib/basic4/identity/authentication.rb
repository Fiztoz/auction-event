require_relative "../errors"
require_relative "user"
require_relative "adapters/mongo_user_repository"
require_relative "adapters/bcrypt_password_hasher"

module Basic4
  module Identity
    class Authentication
      def initialize(user_repository:, password_hasher:)
        @user_repository = user_repository
        @password_hasher = password_hasher
      end

      def self.default
        new(
          user_repository: Adapters::MongoUserRepository.new,
          password_hasher: Adapters::BcryptPasswordHasher.new
        )
      end

      def self.call(email:, password:)
        default.call(email: email, password: password)
      end

      def call(email:, password:)
        email = email.to_s.strip.downcase
        doc = @user_repository.find_by_email(email)
        raise Basic4::ValidationError.new(:credentials, "invalid email or password") unless doc

        hash = doc["password_hash"] || doc[:password_hash]
        unless @password_hasher.verify(password.to_s, hash)
          raise Basic4::ValidationError.new(:credentials, "invalid email or password")
        end

        User.public_view(doc)
      end
    end
  end
end
