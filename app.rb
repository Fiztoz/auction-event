require "sinatra/base"
require "sinatra/json"
require "json"
require "dotenv/load" if File.exist?(File.expand_path("../.env", __FILE__))

require_relative "lib/basic4/shared/shared"
require_relative "lib/basic4/shared/db"
require_relative "lib/basic4/shared/result"
require_relative "lib/basic4/shared/user"
require_relative "lib/basic4/shared/user_presenter"
require_relative "lib/basic4/shared/container"

require_relative "lib/basic4/check_existing/application/inputs"
require_relative "lib/basic4/check_existing/application/check_email"

require_relative "lib/basic4/register/application/inputs"
require_relative "lib/basic4/register/application/register_user"

require_relative "lib/basic4/verify_token/application/verify_email_token"
require_relative "lib/basic4/verify_token/application/resend_email_token"

require_relative "lib/basic4/credit_scoring/application/inputs"
require_relative "lib/basic4/credit_scoring/application/compute_credit_score"

require_relative "lib/basic4/identity/application/inputs"
require_relative "lib/basic4/identity/application/authenticate_user"
require_relative "lib/basic4/identity/application/update_profile"
require_relative "lib/basic4/identity/application/request_password_reset"
require_relative "lib/basic4/identity/application/reset_password"

module Basic4
  class OnboardingApp < Sinatra::Base
    set :root, File.expand_path("..", __FILE__)
    set :public_folder, File.expand_path("../public", __FILE__)
    set :views, File.expand_path("../views", __FILE__)
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET", SecureRandom.hex(32))

    Present = Basic4::UserPresenter

    configure :production, :development do
      begin
        Basic4::DB.ensure_indexes!
      rescue Mongo::Error => e
        warn "[basic4] could not create indexes: #{e.message}"
      end
    end

    helpers do
      def json_body
        @json_body ||= JSON.parse(request.body.read)
      rescue JSON::ParserError
        halt 400, json(error: "invalid JSON")
      end

      def current_user
        return nil unless session[:user_id]
        Basic4::Container.production[:user_repository].find_by_id(session[:user_id])
      end

      def require_user!
        halt 401, json(error: "not signed in") unless session[:user_id]
      end

      def respond_with(result, success_status: 200, failure_status: 422, &on_success)
        case result
        in Basic4::Result::Success(value:)
          status success_status
          on_success.call(value)
        in Basic4::Result::Failure(field:, message:)
          status failure_status
          json error: message, field: field
        end
      end
    end

    get "/" do
      erb :index
    end

    get "/api/health" do
      json status: "ok", db: (Basic4::DB.client.database.command(ping: 1).ok? ? "up" : "down")
    rescue => e
      status 503
      json status: "degraded", error: e.message
    end

    get "/api/me" do
      user = current_user
      halt 401, json(error: "not signed in") unless user
      json user: Present.call(user)
    end

    post "/api/check-existing" do
      body = json_body
      result = Basic4::CheckExisting::Application::CheckEmail.call(
        Basic4::CheckExisting::Application::Inputs::CheckEmail.new(email: body["email"])
      )
      respond_with(result) { |v| json exists: v[:exists] }
    end

    post "/api/signup" do
      body = json_body
      result = Basic4::Register::Application::RegisterUser.call(
        Basic4::Register::Application::Inputs::Signup.new(
          email: body["email"], password: body["password"], name: body["name"]
        )
      )
      respond_with(result, success_status: 201) do |user|
        session[:user_id] = user.id
        json user: Present.call(user)
      end
    end

    post "/api/login" do
      body = json_body
      result = Basic4::Identity::Application::AuthenticateUser.call(
        Basic4::Identity::Application::Inputs::Login.new(email: body["email"], password: body["password"])
      )
      respond_with(result, failure_status: 401) do |user|
        session[:user_id] = user.id
        json user: Present.call(user)
      end
    end

    post "/api/password/forgot" do
      body = json_body
      Basic4::Identity::Application::RequestPasswordReset.call(
        Basic4::Identity::Application::Inputs::PasswordResetRequest.new(email: body["email"])
      )
      json ok: true
    end

    post "/api/password/reset" do
      body = json_body
      result = Basic4::Identity::Application::ResetPassword.call(
        Basic4::Identity::Application::Inputs::PasswordResetSubmit.new(
          token: body["token"], new_password: body["new_password"]
        )
      )
      respond_with(result) { json ok: true }
    end

    patch "/api/profile" do
      require_user!
      body = json_body
      result = Basic4::Identity::Application::UpdateProfile.call(
        session[:user_id],
        Basic4::Identity::Application::Inputs::ProfileUpdate.new(
          name:             body["name"],
          email:            body["email"],
          current_password: body["current_password"],
          new_password:     body["new_password"]
        )
      )
      respond_with(result) { |user| json user: Present.call(user) }
    end

    post "/api/onboarding/verify-email" do
      require_user!
      body = json_body
      result = Basic4::VerifyToken::Application::VerifyEmailToken.call(
        session[:user_id], token: body["token"]
      )
      respond_with(result) { |user| json user: Present.call(user) }
    end

    post "/api/onboarding/resend-token" do
      require_user!
      result = Basic4::VerifyToken::Application::ResendEmailToken.call(session[:user_id])
      respond_with(result) { |user| json user: Present.call(user) }
    end

    post "/api/onboarding/credit-score" do
      require_user!
      body = json_body
      result = Basic4::CreditScoring::Application::ComputeCreditScore.call(
        session[:user_id],
        Basic4::CreditScoring::Application::Inputs::CreditScoreSubmission.new(
          income:        body["income"],
          employment:    body["employment"],
          debt:          body["debt"],
          history_years: body["history_years"]
        )
      )
      respond_with(result) { |user| json user: Present.call(user) }
    end

    post "/api/signout" do
      session.clear
      json ok: true
    end

    if app_file == $PROGRAM_NAME
      run!
    end
  end
end
