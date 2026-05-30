require_relative "../errors"
require_relative "user"
require_relative "adapters/mongo_user_repository"
require_relative "adapters/bcrypt_password_hasher"
require_relative "adapters/secure_random_token_generator"
require_relative "adapters/stdout_notifier"
require_relative "adapters/system_clock"

module Basic4
  module Identity
    class PasswordReset
      def initialize(user_repository:, password_hasher:, token_generator:, notifier:, clock:)
        @user_repository = user_repository
        @password_hasher = password_hasher
        @token_generator = token_generator
        @notifier        = notifier
        @clock           = clock
      end

      def self.default
        new(
          user_repository: Adapters::MongoUserRepository.new,
          password_hasher: Adapters::BcryptPasswordHasher.new,
          token_generator: Adapters::SecureRandomTokenGenerator.new,
          notifier:        Adapters::StdoutNotifier.new,
          clock:           Adapters::SystemClock.new
        )
      end

      def self.request(email)
        default.request(email)
      end

      def self.reset(token:, new_password:)
        default.reset(token: token, new_password: new_password)
      end

      def request(email)
        email = email.to_s.strip.downcase
        return false unless email.match?(User::EMAIL_REGEX)

        doc = @user_repository.find_by_email(email)
        return false unless doc

        token = @token_generator.password_reset_token
        now   = @clock.now
        @user_repository.update(doc["_id"], set: {
          "password_reset" => {
            "token" => token,
            "expires_at" => now + User::PASSWORD_RESET_TTL_SECONDS
          },
          "updated_at" => now
        })
        @notifier.password_reset_token(email, token)
        true
      end

      def reset(token:, new_password:)
        token = token.to_s.strip
        raise Basic4::ValidationError.new(:token, "invalid or expired token") if token.empty?

        if new_password.to_s.length < User::MIN_PASSWORD_LENGTH
          raise Basic4::ValidationError.new(:new_password, "password must be #{User::MIN_PASSWORD_LENGTH}+ chars")
        end

        doc = @user_repository.find_by_password_reset_token(token)
        raise Basic4::ValidationError.new(:token, "invalid or expired token") unless doc

        pr = doc["password_reset"] || {}
        expires_at = pr["expires_at"]
        if expires_at.nil? || expires_at < @clock.now
          raise Basic4::ValidationError.new(:token, "invalid or expired token")
        end

        @user_repository.update(
          doc["_id"],
          set:   { "password_hash" => @password_hasher.hash(new_password), "updated_at" => @clock.now },
          unset: { "password_reset" => "" }
        )
        true
      end
    end
  end
end
