require "sinatra/base"
require "sinatra/json"
require "json"
require "dotenv/load" if File.exist?(File.expand_path("../.env", __FILE__))

require_relative "lib/basic4/db"
require_relative "lib/basic4/user"

module Basic4
  class OnboardingApp < Sinatra::Base
    set :root, File.expand_path("..", __FILE__)
    set :public_folder, File.expand_path("../public", __FILE__)
    set :views, File.expand_path("../views", __FILE__)
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET", SecureRandom.hex(32))

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
        Basic4::User.find(session[:user_id])
      end

      def require_user!
        halt 401, json(error: "not signed in") unless session[:user_id]
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
      json user: user
    end

    post "/api/signup" do
      body = json_body
      user = Basic4::User.signup(
        email: body["email"],
        password: body["password"],
        name: body["name"]
      )
      session[:user_id] = user[:id]
      status 201
      json user: user
    rescue Basic4::User::ValidationError => e
      status 422
      json error: e.message, field: e.field
    end

    post "/api/onboarding/verify-email" do
      require_user!
      body = json_body
      user = Basic4::User.verify_email_token(session[:user_id], token: body["token"])
      json user: user
    rescue Basic4::User::ValidationError => e
      status 422
      json error: e.message, field: e.field
    end

    post "/api/onboarding/resend-token" do
      require_user!
      user = Basic4::User.resend_token(session[:user_id])
      json user: user
    rescue Basic4::User::ValidationError => e
      status 422
      json error: e.message, field: e.field
    end

    post "/api/onboarding/credit-score" do
      require_user!
      body = json_body
      user = Basic4::User.save_credit_score(
        session[:user_id],
        income:        body["income"],
        employment:    body["employment"],
        debt:          body["debt"],
        history_years: body["history_years"]
      )
      json user: user
    rescue Basic4::User::ValidationError => e
      status 422
      json error: e.message, field: e.field
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
