require_relative "../shared"
require_relative "../db"
require_relative "../user"
require_relative "../ports/user_repository"

module Basic4::Infrastructure::MongoUserRepository
  DuplicateEmail = Basic4::Ports::UserRepository::DuplicateEmail

  def self.find_by_id(id)
    doc = Basic4::DB.users.find(_id: id).first
    doc && hydrate(doc)
  end

  def self.find_by_email(email)
    doc = Basic4::DB.users.find(email: email).first
    doc && hydrate(doc)
  end

  def self.find_by_password_reset_token(token)
    doc = Basic4::DB.users.find("password_reset.token" => token).first
    doc && hydrate(doc)
  end

  def self.find_pending_sellers
    Basic4::DB.users.find(step: "credit_scoring", "credit_score" => { "$ne" => nil }).to_a.map { |doc| hydrate(doc) }
  end

  def self.store(user)
    Basic4::DB.users.find_one_and_replace({ _id: user.id }, serialize(user), upsert: true)
    nil
  rescue Mongo::Error::OperationFailure => e
    raise DuplicateEmail if e.message.include?("E11000")
    raise
  end

  def self.hydrate(doc)
    Basic4::User.new(
      id:                  doc["_id"],
      email:               doc["email"],
      name:                doc["name"],
      password_hash:       doc["password_hash"],
      # Pre-role docs: anyone who completed credit scoring was a seller.
      role:                doc["role"] || (doc["credit_score"] ? "seller" : "buyer"),
      step:                doc["step"],
      email_verification:  hydrate_ev(doc["email_verification"]),
      credit_score:        hydrate_cs(doc["credit_score"]),
      shipping_address:    hydrate_sa(doc["shipping_address"]),
      password_reset:      hydrate_pr(doc["password_reset"]),
      created_at:          doc["created_at"],
      updated_at:          doc["updated_at"]
    )
  end

  def self.hydrate_sa(h)
    return nil unless h
    Basic4::ShippingAddress.new(
      line1:       h["line1"],
      line2:       h["line2"],
      city:        h["city"],
      region:      h["region"],
      postal_code: h["postal_code"],
      country:     h["country"]
    )
  end

  def self.hydrate_ev(h)
    return nil unless h
    Basic4::EmailVerification.new(
      token:       h["token"],
      expires_at:  h["expires_at"],
      verified_at: h["verified_at"]
    )
  end

  def self.hydrate_cs(h)
    return nil unless h
    Basic4::CreditScoreSnapshot.new(
      score:       h["score"],
      inputs:      h["inputs"],
      computed_at: h["computed_at"]
    )
  end

  def self.hydrate_pr(h)
    return nil unless h
    Basic4::PasswordReset.new(token: h["token"], expires_at: h["expires_at"])
  end

  def self.serialize(user)
    {
      "_id"                => user.id,
      "email"              => user.email,
      "name"               => user.name,
      "password_hash"      => user.password_hash,
      "role"               => user.role,
      "step"               => user.step,
      "email_verification" => serialize_ev(user.email_verification),
      "credit_score"       => serialize_cs(user.credit_score),
      "shipping_address"   => serialize_sa(user.shipping_address),
      "password_reset"     => serialize_pr(user.password_reset),
      "created_at"         => user.created_at,
      "updated_at"         => user.updated_at
    }
  end

  def self.serialize_sa(sa)
    return nil unless sa
    {
      "line1" => sa.line1, "line2" => sa.line2, "city" => sa.city,
      "region" => sa.region, "postal_code" => sa.postal_code, "country" => sa.country
    }
  end

  def self.serialize_ev(ev)
    return nil unless ev
    { "token" => ev.token, "expires_at" => ev.expires_at, "verified_at" => ev.verified_at }
  end

  def self.serialize_cs(cs)
    return nil unless cs
    { "score" => cs.score, "inputs" => cs.inputs, "computed_at" => cs.computed_at }
  end

  def self.serialize_pr(pr)
    return nil unless pr
    { "token" => pr.token, "expires_at" => pr.expires_at }
  end
end
