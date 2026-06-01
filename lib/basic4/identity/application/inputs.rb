require_relative "../../shared/shared"

module Basic4::Identity::Application::Inputs
  Login                = Data.define(:email, :password)
  ProfileUpdate        = Data.define(:name, :email, :current_password, :new_password)
  PasswordResetRequest = Data.define(:email)
  PasswordResetSubmit  = Data.define(:token, :new_password)
end
