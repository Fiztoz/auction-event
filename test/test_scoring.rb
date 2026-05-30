require "minitest/autorun"
require_relative "../lib/basic4/scoring"

class TestScoring < Minitest::Test
  S = Basic4::Scoring

  def test_baseline_employed_5_years
    assert_equal 655, S.score(income: 80_000, employment: "employed", debt: 10_000, history_years: 5)
  end

  def test_income_points_cap_at_150
    high  = S.score(income: 500_000, employment: "employed", debt: 0, history_years: 0)
    just  = S.score(income: 150_000, employment: "employed", debt: 0, history_years: 0)
    assert_equal high, just
  end

  def test_history_years_cap_at_75
    long   = S.score(income: 50_000, employment: "employed", debt: 0, history_years: 30)
    fifteen = S.score(income: 50_000, employment: "employed", debt: 0, history_years: 15)
    assert_equal long, fifteen
  end

  def test_high_dti_penalty
    low_dti  = S.score(income: 100_000, employment: "employed", debt: 10_000, history_years: 0)
    high_dti = S.score(income: 100_000, employment: "employed", debt: 60_000, history_years: 0)
    assert_equal 100, low_dti - high_dti
  end

  def test_unemployed_minimum_inputs_clamps_to_floor_band
    assert S.score(income: 0, employment: "unemployed", debt: 0, history_years: 0) >= 300
  end

  def test_extreme_inputs_stay_within_band
    high = S.score(income: 1_000_000, employment: "employed", debt: 0, history_years: 100)
    low  = S.score(income: 0,         employment: "unemployed", debt: 1_000_000, history_years: 0)
    assert (300..850).cover?(high), "high inputs out of band: #{high}"
    assert (300..850).cover?(low),  "low inputs out of band: #{low}"
    assert_equal 775, high
    assert_equal 350, low
  end

  def test_validate_rejects_negative_income
    err = assert_raises(S::InvalidInput) do
      S.validate!(income: -1, employment: "employed", debt: 0, history_years: 0)
    end
    assert_equal :income, err.field
  end

  def test_validate_rejects_unknown_employment
    err = assert_raises(S::InvalidInput) do
      S.validate!(income: 50_000, employment: "ceo", debt: 0, history_years: 0)
    end
    assert_equal :employment, err.field
  end

  def test_validate_rejects_non_numeric_income
    err = assert_raises(S::InvalidInput) do
      S.validate!(income: "lots", employment: "employed", debt: 0, history_years: 0)
    end
    assert_equal :income, err.field
  end
end
