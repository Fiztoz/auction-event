require_relative "shared"
require_relative "user"

module Basic4::UserPresenter
  def self.call(user)
    {
      id:             user.id,
      email:          user.email,
      name:           user.name,
      role:           user.role,
      step:           user.step,
      email_verified: !!user.email_verification&.verified?,
      credit_score:   user.credit_score && {
        score:       user.credit_score.score,
        computed_at: user.credit_score.computed_at
      },
      shipping_address: user.shipping_address && {
        line1:       user.shipping_address.line1,
        line2:       user.shipping_address.line2,
        city:        user.shipping_address.city,
        region:      user.shipping_address.region,
        postal_code: user.shipping_address.postal_code,
        country:     user.shipping_address.country
      },
      created_at:     user.created_at
    }
  end
end
