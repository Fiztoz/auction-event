require_relative "../../identity"
require_relative "../../db"
require_relative "../ports/user_repository"
require_relative "../domain/user"

module Basic4::Identity::Infrastructure::MongoUserRepository
  D              = Basic4::Identity::Domain
  DuplicateEmail = Basic4::Identity::Ports::UserRepository::DuplicateEmail

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

  def self.store(user)
    Basic4::DB.users.find_one_and_replace({ _id: user.id }, serialize(user), upsert: true)
    nil
  rescue Mongo::Error::OperationFailure => e
    raise DuplicateEmail if e.message.include?("E11000")
    raise
  end

  def self.hydrate(doc)
    D::User.new(
      id:                  doc["_id"],
      email:               doc["email"],
      name:                doc["name"],
      password_hash:       doc["password_hash"],
      step:                doc["step"],
      email_verification:  hydrate_ev(doc["email_verification"]),
      credit_score:        hydrate_cs(doc["credit_score"]),
      password_reset:      hydrate_pr(doc["password_reset"]),
      created_at:          doc["created_at"],
      updated_at:          doc["updated_at"]
    )
  end

  def self.hydrate_ev(h)
    return nil unless h
    D::EmailVerification.new(
      token:       h["token"],
      expires_at:  h["expires_at"],
      verified_at: h["verified_at"]
    )
  end

  def self.hydrate_cs(h)
    return nil unless h
    D::CreditScoreSnapshot.new(
      score:       h["score"],
      inputs:      h["inputs"],
      computed_at: h["computed_at"]
    )
  end

  def self.hydrate_pr(h)
    return nil unless h
    D::PasswordReset.new(token: h["token"], expires_at: h["expires_at"])
  end

  def self.serialize(user)
    {
      "_id"                => user.id,
      "email"              => user.email,
      "name"               => user.name,
      "password_hash"      => user.password_hash,
      "step"               => user.step,
      "email_verification" => serialize_ev(user.email_verification),
      "credit_score"       => serialize_cs(user.credit_score),
      "password_reset"     => serialize_pr(user.password_reset),
      "created_at"         => user.created_at,
      "updated_at"         => user.updated_at
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
