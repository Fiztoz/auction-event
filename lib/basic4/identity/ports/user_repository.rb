module Basic4
  module Identity
    module Ports
      # Persistence port for the User aggregate.
      #
      # Concrete adapter: lib/basic4/identity/adapters/mongo_user_repository.rb
      #
      # Required instance methods:
      #   find_by_id(id)                       -> Hash | nil
      #   find_by_email(email)                 -> Hash | nil
      #   find_by_password_reset_token(token)  -> Hash | nil
      #   insert(doc)                          -> doc          (raises DuplicateEmail)
      #   update(id, set: {}, unset: nil)      -> nil          (raises DuplicateEmail)
      #   find_one_and_update(id, set: {})     -> Hash | nil   (raises DuplicateEmail)
      module UserRepository
        class DuplicateEmail < StandardError; end
      end
    end
  end
end
