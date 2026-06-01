require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/user"
require_relative "../../shared/container"
require_relative "inputs"

module Basic4::CheckExisting::Application::CheckEmail
  module_function

  def call(input, container: Basic4::Container.production)
    repo  = container[:user_repository]
    email = input.email.to_s.strip.downcase
    return Basic4::Result.failure(:email, "invalid email") unless email.match?(Basic4::User::EMAIL_REGEX)
    Basic4::Result.success(exists: !repo.find_by_email(email).nil?)
  end
end
