require_relative "shared"
require_relative "infrastructure/mongo_user_repository"
require_relative "infrastructure/mongo_product_repository"
require_relative "infrastructure/bcrypt_password_hasher"
require_relative "infrastructure/secure_random_token_generator"
require_relative "infrastructure/stdout_notifier"
require_relative "infrastructure/system_clock"
require_relative "infrastructure/minio_object_storage"

module Basic4::Container
  I = Basic4::Infrastructure

  def self.production
    @production ||= {
      user_repository:    I::MongoUserRepository,
      product_repository: I::MongoProductRepository,
      password_hasher: I::BcryptPasswordHasher,
      tokens:          I::SecureRandomTokenGenerator,
      notifier:        I::StdoutNotifier,
      clock:           I::SystemClock,
      object_storage:  I::MinioObjectStorage
    }.freeze
  end
end
