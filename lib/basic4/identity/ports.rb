module Basic4; module Identity; end; end

module Basic4::Identity::Ports
  # Persistence port for the User aggregate.
  #
  # Required module methods on adapters:
  #   find_by_id(id)                       -> Hash | nil
  #   find_by_email(email)                 -> Hash | nil
  #   find_by_password_reset_token(token)  -> Hash | nil
  #   insert(doc)                          -> doc          (raises DuplicateEmail)
  #   update(id, set: {}, unset: nil)      -> nil          (raises DuplicateEmail)
  #   find_one_and_update(id, set: {})     -> Hash | nil   (raises DuplicateEmail)
  module UserRepository
    class DuplicateEmail < StandardError; end
  end

  # Password hashing port.
  # Required: hash(plain) -> String;  verify(plain, stored_hash) -> Boolean
  module PasswordHasher; end

  # Random identifier + token generation port.
  # Required: user_id, email_token, password_reset_token (all -> String)
  module TokenGenerator; end

  # Outbound notification port — how the user receives codes/links.
  # Required:
  #   email_verification_token(email, token) -> nil
  #   password_reset_token(email, token)     -> nil
  module Notifier; end

  # Time port — abstracts "now" so domain logic can be tested
  # without freezing real time.
  # Required: now -> Time (UTC)
  module Clock; end
end
