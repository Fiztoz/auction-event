module Basic4; end

module Basic4::Scoring
  EMPLOYMENT_POINTS = {
    "employed"      => 50,
    "self_employed" => 30,
    "student"       => 0,
    "unemployed"    => -50
  }.freeze

  SCORE_MIN = 300
  SCORE_MAX = 850

  class InvalidInput < StandardError
    attr_reader :field
    def initialize(field, message)
      @field = field
      super(message)
    end
  end

  def self.validate!(income:, employment:, debt:, history_years:)
    income_f = non_negative_float(income, :income)
    debt_f   = non_negative_float(debt, :debt)
    years_i  = non_negative_integer(history_years, :history_years)

    employment_s = employment.to_s
    unless EMPLOYMENT_POINTS.key?(employment_s)
      raise InvalidInput.new(:employment, "invalid employment status")
    end

    { income: income_f, employment: employment_s, debt: debt_f, history_years: years_i }
  end

  def self.score(income:, employment:, debt:, history_years:)
    income_pts  = [income / 1000.0, 150].min
    emp_pts     = EMPLOYMENT_POINTS.fetch(employment, 0)
    history_pts = [history_years * 5, 75].min

    dti = debt.to_f / [income, 1].max
    dti_pts =
      if dti > 0.5 then -100
      elsif dti >= 0.3 then -50
      else 0
      end

    raw = 500 + income_pts + emp_pts + history_pts + dti_pts
    raw.clamp(SCORE_MIN, SCORE_MAX).to_i
  end

  def self.non_negative_float(value, field)
    n = Float(value)
    raise InvalidInput.new(field, "#{field} must be non-negative") if n < 0
    n
  rescue ArgumentError, TypeError
    raise InvalidInput.new(field, "#{field} must be a number")
  end

  def self.non_negative_integer(value, field)
    n = Integer(value)
    raise InvalidInput.new(field, "#{field} must be non-negative") if n < 0
    n
  rescue ArgumentError, TypeError
    raise InvalidInput.new(field, "#{field} must be an integer")
  end
end
