require "sinatra/base"
require "sinatra/json"
require "json"
require "dotenv/load" if File.exist?(File.expand_path("../.env", __FILE__))

require_relative "lib/basic4/db"
require_relative "lib/basic4/result"
require_relative "lib/basic4/scoring"
require_relative "lib/basic4/identity/container"
require_relative "lib/basic4/identity/application/inputs"
require_relative "lib/basic4/identity/application/user_presenter"
require_relative "lib/basic4/identity/application/register_user"
require_relative "lib/basic4/identity/application/authenticate_user"
require_relative "lib/basic4/identity/application/update_profile"
require_relative "lib/basic4/identity/application/request_password_reset"
require_relative "lib/basic4/identity/application/reset_password"
require_relative "lib/basic4/onboarding/email_verification"
require_relative "lib/basic4/onboarding/credit_scoring"

module Basic4
  class OnboardingApp < Sinatra::Base
    set :root, File.expand_path("..", __FILE__)
    set :public_folder, File.expand_path("../public", __FILE__)
    set :views, File.expand_path("../views", __FILE__)
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET", SecureRandom.hex(32))

    Inputs   = Basic4::Identity::Application::Inputs
    Identity = Basic4::Identity::Application
    Present  = Basic4::Identity::Application::UserPresenter

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
        Basic4::Identity::Container.production[:user_repository].find_by_id(session[:user_id])
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

    post "/api/signup" do
      body = json_body
      result = Identity::RegisterUser.call(
        Inputs::Signup.new(email: body["email"], password: body["password"], name: body["name"])
      )
      respond_with(result, success_status: 201) do |user|
        session[:user_id] = user.id
        json user: Present.call(user)
      end
    end

    post "/api/login" do
      body = json_body
      result = Identity::AuthenticateUser.call(
        Inputs::Login.new(email: body["email"], password: body["password"])
      )
      respond_with(result, failure_status: 401) do |user|
        session[:user_id] = user.id
        json user: Present.call(user)
      end
    end

    post "/api/password/forgot" do
      body = json_body
      Identity::RequestPasswordReset.call(
        Inputs::PasswordResetRequest.new(email: body["email"])
      )
      json ok: true
    end

    post "/api/password/reset" do
      body = json_body
      result = Identity::ResetPassword.call(
        Inputs::PasswordResetSubmit.new(token: body["token"], new_password: body["new_password"])
      )
      respond_with(result) { json ok: true }
    end

    patch "/api/profile" do
      require_user!
      body = json_body
      result = Identity::UpdateProfile.call(
        session[:user_id],
        Inputs::ProfileUpdate.new(
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
      result = Basic4::Onboarding::EmailVerification.verify(session[:user_id], token: body["token"])
      respond_with(result) { |user| json user: Present.call(user) }
    end

    post "/api/onboarding/resend-token" do
      require_user!
      result = Basic4::Onboarding::EmailVerification.resend(session[:user_id])
      respond_with(result) { |user| json user: Present.call(user) }
    end

    post "/api/onboarding/credit-score" do
      require_user!
      body = json_body
      result = Basic4::Onboarding::CreditScoring.save(
        session[:user_id],
        income:        body["income"],
        employment:    body["employment"],
        debt:          body["debt"],
        history_years: body["history_years"]
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
