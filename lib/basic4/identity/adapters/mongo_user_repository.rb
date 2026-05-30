require_relative "../../db"
require_relative "../ports/user_repository"

module Basic4
  module Identity
    module Adapters
      class MongoUserRepository
        DuplicateEmail = Basic4::Identity::Ports::UserRepository::DuplicateEmail

        def initialize(collection: Basic4::DB.users)
          @collection = collection
        end

        def find_by_id(id)
          @collection.find(_id: id).first
        end

        def find_by_email(email)
          @collection.find(email: email).first
        end

        def find_by_password_reset_token(token)
          @collection.find("password_reset.token" => token).first
        end

        def insert(doc)
          @collection.insert_one(doc)
          doc
        rescue Mongo::Error::OperationFailure => e
          raise DuplicateEmail if e.message.include?("E11000")
          raise
        end

        def update(id, set: {}, unset: nil)
          ops = { "$set" => set }
          ops["$unset"] = unset if unset
          @collection.update_one({ _id: id }, ops)
          nil
        rescue Mongo::Error::OperationFailure => e
          raise DuplicateEmail if e.message.include?("E11000")
          raise
        end

        def find_one_and_update(id, set:)
          @collection.find_one_and_update({ _id: id }, { "$set" => set }, return_document: :after)
        rescue Mongo::Error::OperationFailure => e
          raise DuplicateEmail if e.message.include?("E11000")
          raise
        end
      end
    end
  end
end
