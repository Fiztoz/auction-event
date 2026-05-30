require_relative "../errors"
require_relative "user"
require_relative "ports/user_repository"
require_relative "adapters/mongo_user_repository"
require_relative "adapters/bcrypt_password_hasher"
require_relative "adapters/secure_random_token_generator"
require_relative "adapters/stdout_notifier"
require_relative "adapters/system_clock"

module Basic4
  module Identity
    class Registration
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

      def self.signup(email:, password:, name:)
        default.signup(email: email, password: password, name: name)
      end

      def signup(email:, password:, name:)
        email = email.to_s.strip.downcase
        name  = name.to_s.strip
        unless email.match?(User::EMAIL_REGEX)
          raise Basic4::ValidationError.new(:email, "invalid email")
        end
        if password.to_s.length < User::MIN_PASSWORD_LENGTH
          raise Basic4::ValidationError.new(:password, "password must be #{User::MIN_PASSWORD_LENGTH}+ chars")
        end
        raise Basic4::ValidationError.new(:name, "name required") if name.empty?

        now   = @clock.now
        token = @token_generator.email_token
        doc = {
          _id: @token_generator.user_id,
          email: email,
          name: name,
          password_hash: @password_hasher.hash(password),
          step: "verify_email",
          email_verification: {
            token: token,
            expires_at: now + User::TOKEN_TTL_SECONDS,
            verified_at: nil
          },
          credit_score: nil,
          created_at: now,
          updated_at: now
        }

        begin
          @user_repository.insert(doc)
        rescue Ports::UserRepository::DuplicateEmail
          raise Basic4::ValidationError.new(:email, "email already registered")
        end

        @notifier.email_verification_token(email, token)
        User.public_view(doc)
      end
    end
  end
end
