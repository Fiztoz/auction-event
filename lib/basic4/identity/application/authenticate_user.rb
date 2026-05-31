require_relative "../../identity"
require_relative "../../result"
require_relative "../container"
require_relative "inputs"

module Basic4::Identity::Application::AuthenticateUser
  module_function

  def call(input, container: Basic4::Identity::Container.production)
    repo   = container[:user_repository]
    hasher = container[:password_hasher]

    email    = input.email.to_s.strip.downcase
    password = input.password.to_s

    user = repo.find_by_email(email)
    return Basic4::Result.failure(:credentials, "invalid email or password") unless user

    unless hasher.verify(password, user.password_hash)
      return Basic4::Result.failure(:credentials, "invalid email or password")
    end

    Basic4::Result.success(user)
  end
end
