module Basic4; module Identity; end; end

module Basic4::Identity::Inputs
  Signup               = Data.define(:email, :password, :name)
  Login                = Data.define(:email, :password)
  ProfileUpdate        = Data.define(:name, :email, :current_password, :new_password)
  PasswordResetRequest = Data.define(:email)
  PasswordResetSubmit  = Data.define(:token, :new_password)
end
