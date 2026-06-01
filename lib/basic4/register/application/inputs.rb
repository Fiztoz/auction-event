require_relative "../../shared/shared"

module Basic4::Register::Application::Inputs
  Signup = Data.define(:email, :password, :name)
end
