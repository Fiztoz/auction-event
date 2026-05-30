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
    class Profile
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

      def self.update(user_id, **kwargs)
        default.update(user_id, **kwargs)
      end

      def update(user_id, name: nil, email: nil, current_password: nil, new_password: nil)
        doc = @user_repository.find_by_id(user_id)
        raise Basic4::ValidationError.new(:user, "user not found") unless doc

        new_name  = name.is_a?(String) ? name.strip : nil
        new_email = email.is_a?(String) ? email.strip.downcase : nil
        changing_email    = new_email && !new_email.empty? && new_email != doc["email"]
        changing_password = new_password.is_a?(String) && !new_password.empty?

        if new_name && new_name.empty?
          raise Basic4::ValidationError.new(:name, "name cannot be empty")
        end

        if changing_email && !new_email.match?(User::EMAIL_REGEX)
          raise Basic4::ValidationError.new(:email, "invalid email")
        end

        if changing_password && new_password.length < User::MIN_PASSWORD_LENGTH
          raise Basic4::ValidationError.new(:new_password, "password must be #{User::MIN_PASSWORD_LENGTH}+ chars")
        end

        if changing_email || changing_password
          if current_password.to_s.empty?
            raise Basic4::ValidationError.new(:current_password, "current password required")
          end
          unless @password_hasher.verify(current_password.to_s, doc["password_hash"])
            raise Basic4::ValidationError.new(:current_password, "current password is incorrect")
          end
        end

        now = @clock.now
        set = { "updated_at" => now }
        set["name"] = new_name if new_name && !new_name.empty?
        set["password_hash"] = @password_hasher.hash(new_password) if changing_password

        token = nil
        if changing_email
          token = @token_generator.email_token
          set["email"] = new_email
          set["step"]  = "verify_email"
          set["email_verification"] = {
            "token" => token,
            "expires_at" => now + User::TOKEN_TTL_SECONDS,
            "verified_at" => nil
          }
        end

        begin
          updated = @user_repository.find_one_and_update(user_id, set: set)
        rescue Ports::UserRepository::DuplicateEmail
          raise Basic4::ValidationError.new(:email, "email already registered")
        end

        @notifier.email_verification_token(new_email, token) if changing_email
        User.public_view(updated)
      end
    end
  end
end
