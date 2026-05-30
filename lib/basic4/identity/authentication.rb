require_relative "../result"
require_relative "user"
require_relative "inputs"
require_relative "adapters"

module Basic4; module Identity; end; end

module Basic4::Identity::Authentication
  module_function

  def call(input,
           repo:   Basic4::Identity::Adapters::MongoUserRepo,
           hasher: Basic4::Identity::Adapters::BcryptHasher)
    normalized = Basic4::Identity::Inputs::Login.new(
      email:    input.email.to_s.strip.downcase,
      password: input.password.to_s
    )

    doc = repo.find_by_email(normalized.email)
    return Basic4::Result.failure(:credentials, "invalid email or password") unless doc

    hash = doc["password_hash"] || doc[:password_hash]
    unless hasher.verify(normalized.password, hash)
      return Basic4::Result.failure(:credentials, "invalid email or password")
    end

    Basic4::Result.success(Basic4::Identity::User.public_view(doc))
  end
end
