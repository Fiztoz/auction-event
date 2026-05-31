require_relative "../identity"
require_relative "infrastructure/mongo_user_repository"
require_relative "infrastructure/bcrypt_password_hasher"
require_relative "infrastructure/secure_random_token_generator"
require_relative "infrastructure/stdout_notifier"
require_relative "infrastructure/system_clock"

module Basic4::Identity::Container
  I = Basic4::Identity::Infrastructure

  def self.production
    @production ||= {
      user_repository: I::MongoUserRepository,
      password_hasher: I::BcryptPasswordHasher,
      tokens:          I::SecureRandomTokenGenerator,
      notifier:        I::StdoutNotifier,
      clock:           I::SystemClock
    }.freeze
  end
end
