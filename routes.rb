module Basic4
  class OnboardingApp < Sinatra::Base
    # ── system ────────────────────────────────────────────────────

    # Home is the public storefront. The onboarding / sign-in SPA lives at /app.
    get "/" do
      erb :browse
    end

    get "/app" do
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

    # ── pre-signup ────────────────────────────────────────────────

    post "/api/check-existing" do
      body = json_body
      result = Basic4::CheckExisting::Application::CheckEmail.call(
        Basic4::CheckExisting::Application::Inputs::CheckEmail.new(email: body["email"])
      )
      respond_with(result) { |v| json exists: v[:exists] }
    end

    # ── auth ──────────────────────────────────────────────────────

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

    # ── onboarding ────────────────────────────────────────────────

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

    post "/api/onboarding/shipping-address" do
      require_user!
      body = json_body
      result = Basic4::BuyerOnboarding::Application::SaveShippingAddress.call(
        session[:user_id],
        Basic4::BuyerOnboarding::Application::Inputs::ShippingAddress.new(
          line1:       body["line1"],
          line2:       body["line2"],
          city:        body["city"],
          region:      body["region"],
          postal_code: body["postal_code"],
          country:     body["country"]
        )
      )
      respond_with(result) { |user| json user: Present.call(user) }
    end

    post "/api/onboarding/become-seller" do
      require_user!
      result = Basic4::CreditScoring::Application::StartSellerApplication.call(session[:user_id])
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

    # ── public catalog ────────────────────────────────────────────

    get "/browse" do
      erb :browse
    end

    get "/api/products" do
      products = Basic4::ProductAuction::Application::BrowseProducts.call
      json products: products.map { |product| PresentProduct.call(product) }
    end

    post "/api/products/:id/bid" do
      require_user!
      body = json_body
      result = Basic4::ProductAuction::Application::PlaceBid.call(
        session[:user_id], params["id"], body["amount_cents"]
      )
      respond_with(result) { |product| json product: PresentProduct.call(product) }
    end

    # ── selling ───────────────────────────────────────────────────

    post "/api/products" do
      require_seller!
      body = json_body
      result = Basic4::ProductAuction::Application::ListProductForAuction.call(
        session[:user_id], product_input(body)
      )
      respond_with(result, success_status: 201) { |product| json product: PresentProduct.call(product) }
    end

    put "/api/products/:id" do
      require_seller!
      body = json_body
      result = Basic4::ProductAuction::Application::UpdateAuction.call(
        session[:user_id], params["id"], product_input(body)
      )
      respond_with(result) { |product| json product: PresentProduct.call(product) }
    end

    post "/api/products/:id/start" do
      require_seller!
      result = Basic4::ProductAuction::Application::StartAuction.call(
        session[:user_id], params["id"]
      )
      respond_with(result) { |product| json product: PresentProduct.call(product) }
    end

    post "/api/products/:id/stop" do
      require_seller!
      result = Basic4::ProductAuction::Application::StopAuction.call(
        session[:user_id], params["id"]
      )
      respond_with(result) { |product| json product: PresentProduct.call(product) }
    end

    post "/api/products/images" do
      require_seller!
      file = params["file"]
      halt 422, json(error: "no file uploaded", field: "image") unless file.is_a?(Hash) && file[:tempfile]
      result = Basic4::ProductAuction::Application::UploadImage.call(
        session[:user_id],
        io:           file[:tempfile],
        content_type: file[:type],
        size:         file[:tempfile].size
      )
      respond_with(result, success_status: 201) { |v| json url: v[:url] }
    end

    get "/api/products/mine" do
      require_seller!
      products = Basic4::ProductAuction::Application::ListMyAuctions.call(session[:user_id])
      json products: products.map { |product| PresentProduct.call(product) }
    end

    # Public single-auction detail + full bid history. Declared AFTER
    # "/api/products/mine" so the :id wildcard doesn't swallow that path.
    get "/api/products/:id" do
      found = Basic4::ProductAuction::Application::ShowAuction.call(params["id"])
      halt 404, json(error: "not found") unless found
      json product: PresentProduct.call(found[:product]),
           bids:    found[:bids].map { |bid| PresentBid.call(bid, viewer_id: session[:user_id]) }
    end

    # ── admin (back office) ───────────────────────────────────────

    # Read-only admin console. The page itself gates on /api/me; the data it
    # shows comes from the admin-only endpoint below.
    get "/admin" do
      erb :admin
    end

    # Admins may see closed auctions only — never drafts or live listings.
    get "/api/admin/auctions" do
      require_admin!
      products = Basic4::ProductAuction::Application::ListClosedAuctions.call
      json products: products.map { |product| PresentProduct.call(product) }
    end

    # Full back-office view of one closed auction: the listing, its bids, the
    # real identities of seller + winner, and the settlement (if opened). Declared
    # after the collection route so the :id wildcard doesn't swallow it.
    get "/api/admin/auctions/:id" do
      require_admin!
      found = Basic4::Settlement::Application::AdminAuctionDetail.call(params["id"])
      halt 404, json(error: "not found") unless found
      json product:    PresentProduct.call(found[:product]),
           bids:       found[:bids].map { |bid| PresentBid.call(bid, viewer_id: session[:user_id]) },
           seller:     PresentSettlement.party(found[:seller]),
           winner:     PresentSettlement.party(found[:winner]),
           settlement: found[:settlement] && PresentSettlement.call(found[:settlement])
    end

    # Settlement queue: every closed auction with a winner, plus its winner and
    # current settlement state — what the admin needs to action, at a glance.
    get "/api/admin/settlements" do
      require_admin!
      rows = Basic4::Settlement::Application::ListSettlementQueue.call
      json items: rows.map { |row|
        {
          product:    PresentProduct.call(row[:product]),
          winner:     PresentSettlement.party(row[:winner]),
          settlement: row[:settlement] && PresentSettlement.call(row[:settlement])
        }
      }
    end

    # Admin opens a settlement by invoicing the winner of an ended auction.
    post "/api/admin/products/:id/settlement" do
      require_admin!
      result = Basic4::Settlement::Application::InvoiceWinner.call(params["id"])
      respond_with(result, success_status: 201) { |s| json settlement: PresentSettlement.call(s) }
    end

    # Admin advances a settlement through its lifecycle.
    post "/api/admin/settlements/:id/payment" do
      require_admin!
      result = Basic4::Settlement::Application::RecordPayment.call(params["id"])
      respond_with(result) { |s| json settlement: PresentSettlement.call(s) }
    end

    post "/api/admin/settlements/:id/shipment" do
      require_admin!
      result = Basic4::Settlement::Application::RecordShipment.call(params["id"])
      respond_with(result) { |s| json settlement: PresentSettlement.call(s) }
    end

    # Releases funds to the seller and marks the auction completed.
    post "/api/admin/settlements/:id/complete" do
      require_admin!
      result = Basic4::Settlement::Application::CompleteSettlement.call(params["id"])
      respond_with(result) { |s| json settlement: PresentSettlement.call(s) }
    end

    # Seller applications: buyers who completed credit scoring and await approval.
    get "/api/admin/seller-applications" do
      require_admin!
      users = Basic4::CreditScoring::Application::ListPendingSellers.call
      json applicants: users.map { |u| Present.call(u) }
    end

    post "/api/admin/seller-applications/:id/approve" do
      require_admin!
      result = Basic4::CreditScoring::Application::ApproveSeller.call(params["id"])
      respond_with(result) { |u| json user: Present.call(u) }
    end

    post "/api/admin/seller-applications/:id/reject" do
      require_admin!
      result = Basic4::CreditScoring::Application::RejectSeller.call(params["id"])
      respond_with(result) { |u| json user: Present.call(u) }
    end

    # ── admin: product approval workflow ────────────────────────────

    # Queue: products awaiting admin approval (oldest first).
    get "/api/admin/pending-products" do
      require_admin!
      products = Basic4::Admin::Application::ListPendingProducts.call
      json products: products.map { |product| PresentProduct.call(product) }
    end

    # Admin approves a pending product: pending_approval -> draft.
    post "/api/admin/products/:id/approve" do
      require_admin!
      result = Basic4::Admin::Application::ApproveProduct.call(
        session[:user_id], params["id"]
      )
      respond_with(result) { |product| json product: PresentProduct.call(product) }
    end

    # Admin rejects a pending product with a reason.
    post "/api/admin/products/:id/reject" do
      require_admin!
      body = json_body
      result = Basic4::Admin::Application::RejectProduct.call(
        session[:user_id], params["id"], reason: body["reason"]
      )
      respond_with(result) { |product| json product: PresentProduct.call(product) }
    end

    # ── notifications ────────────────────────────────────────────

    get "/api/notifications" do
      require_user!
      result = Basic4::Identity::Application::ListNotifications.call(session[:user_id])
      respond_with(result) { |v| json v }
    end

    patch "/api/notifications/:id/read" do
      require_user!
      result = Basic4::Identity::Application::MarkNotificationRead.call(
        session[:user_id], params["id"]
      )
      respond_with(result) { |n| json notification: PresentNotification.call(n) }
    end

    get "/api/notifications/unread-count" do
      require_user!
      container = Basic4::Container.production
      json unread_count: container[:notification_repository].unread_count(session[:user_id])
    end

    # ── account management ────────────────────────────────────────

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

    # ── session ───────────────────────────────────────────────────

    post "/api/signout" do
      session.clear
      json ok: true
    end
  end
end
