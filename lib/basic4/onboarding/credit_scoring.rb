require_relative "../db"
require_relative "../errors"
require_relative "../scoring"
require_relative "../identity/user"

module Basic4
  module Onboarding
    module CreditScoring
      def self.save(user_id, income:, employment:, debt:, history_years:)
        doc = Basic4::DB.users.find(_id: user_id).first
        raise Basic4::ValidationError.new(:user, "user not found") unless doc
        raise Basic4::ValidationError.new(:step, "not at credit scoring step") unless doc["step"] == "credit_scoring"

        begin
          inputs = Basic4::Scoring.validate!(
            income: income, employment: employment, debt: debt, history_years: history_years
          )
          score = Basic4::Scoring.score(**inputs)
        rescue Basic4::Scoring::InvalidInput => e
          raise Basic4::ValidationError.new(e.field, e.message)
        end

        now = Time.now.utc
        updated = Basic4::DB.users.find_one_and_update(
          { _id: user_id },
          { "$set" => {
              credit_score: { score: score, inputs: inputs, computed_at: now },
              step: "done",
              updated_at: now
          } },
          return_document: :after
        )
        Basic4::Identity::User.public_view(updated)
      end
    end
  end
end
