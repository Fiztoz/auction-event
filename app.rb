require "sinatra/base"
require "sinatra/json"
require "json"
require "dotenv/load" if File.exist?(File.expand_path("../.env", __FILE__))

require_relative "lib/basic4/shared/shared"
require_relative "lib/basic4/shared/db"
require_relative "lib/basic4/shared/result"
require_relative "lib/basic4/shared/user"
require_relative "lib/basic4/shared/user_presenter"
require_relative "lib/basic4/shared/product"
require_relative "lib/basic4/shared/product_presenter"
require_relative "lib/basic4/shared/ports/product_repository"
require_relative "lib/basic4/shared/ports/object_storage"
require_relative "lib/basic4/shared/container"

require_relative "lib/basic4/check_existing/application/inputs"
require_relative "lib/basic4/check_existing/application/check_email"

require_relative "lib/basic4/register/application/inputs"
require_relative "lib/basic4/register/application/register_user"

require_relative "lib/basic4/verify_token/application/verify_email_token"
require_relative "lib/basic4/verify_token/application/resend_email_token"

require_relative "lib/basic4/credit_scoring/application/inputs"
require_relative "lib/basic4/credit_scoring/application/compute_credit_score"
require_relative "lib/basic4/credit_scoring/application/start_seller_application"

require_relative "lib/basic4/buyer_onboarding/application/inputs"
require_relative "lib/basic4/buyer_onboarding/application/save_shipping_address"

require_relative "lib/basic4/identity/application/inputs"
require_relative "lib/basic4/identity/application/authenticate_user"
require_relative "lib/basic4/identity/application/update_profile"
require_relative "lib/basic4/identity/application/request_password_reset"
require_relative "lib/basic4/identity/application/reset_password"

require_relative "lib/basic4/product_auction/application/inputs"
require_relative "lib/basic4/product_auction/application/list_product_for_auction"
require_relative "lib/basic4/product_auction/application/list_my_auctions"
require_relative "lib/basic4/product_auction/application/browse_products"
require_relative "lib/basic4/product_auction/application/update_auction"
require_relative "lib/basic4/product_auction/application/start_auction"
require_relative "lib/basic4/product_auction/application/upload_image"

module Basic4
  class OnboardingApp < Sinatra::Base
    set :root, File.expand_path("..", __FILE__)
    set :public_folder, File.expand_path("../public", __FILE__)
    set :views, File.expand_path("../views", __FILE__)
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET", SecureRandom.hex(32))

    Present = Basic4::UserPresenter
    PresentProduct = Basic4::ProductPresenter

    configure :production, :development do
      begin
        Basic4::DB.ensure_indexes!
      rescue Mongo::Error => e
        warn "[basic4] could not create indexes: #{e.message}"
      end

      begin
        Basic4::Container.production[:object_storage].ensure_bucket!
      rescue => e
        warn "[basic4] could not reach object storage (MinIO): #{e.message}"
      end
    end

    # In development, make the browser revalidate static assets (JS/CSS) instead
    # of serving a heuristically-cached copy — otherwise front-end edits don't
    # show on a plain refresh. Sinatra still sends Last-Modified, so unchanged
    # files come back as cheap 304s. Production keeps its default caching.
    configure :development do
      set :static_cache_control, [:no_cache]
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

      def require_seller!
        require_user!
        halt 403, json(error: "become a seller first") unless current_user&.role == "seller"
      end

      def product_input(body)
        Basic4::ProductAuction::Application::Inputs::ListProduct.new(
          title:                body["title"],
          description:          body["description"],
          category:             body["category"],
          starting_price_cents: body["starting_price_cents"],
          duration_days:        body["duration_days"],
          images:               body["images"]
        )
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
  end
end

require_relative "routes"

if Basic4::OnboardingApp.app_file == $PROGRAM_NAME
  Basic4::OnboardingApp.run!
end
