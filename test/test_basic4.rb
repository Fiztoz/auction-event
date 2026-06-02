require "minitest/autorun"
require "tempfile"
require_relative "../lib/basic4"

class TestBasic4 < Minitest::Test
  def test_version
    refute_nil Basic4::VERSION
  end

  def test_greet_default
    assert_equal "Hello, world!", Basic4.greet
  end

  def test_greet_with_name
    assert_equal "Hello, Ruby!", Basic4.greet("Ruby")
  end

  def test_parallel_greet
    skip "Ractor not supported on this runtime" unless defined?(Ractor)
    assert_equal ["Hello, Ada!", "Hello, Grace!", "Hello, Linus!"],
                 Basic4.parallel_greet(%w[Ada Grace Linus])
  end

  def test_parallel_greet_empty
    skip "Ractor not supported on this runtime" unless defined?(Ractor)
    assert_equal [], Basic4.parallel_greet([])
  end

  def test_report_writes_average_and_rows
    Tempfile.create(["scores", ".csv"]) do |csv|
      csv.write("name,email,score\nAda,ada@x,90\nGrace,grace@x,80\nLinus,linus@x,70\n")
      csv.flush
      Tempfile.create(["report", ".txt"]) do |txt|
        assert_in_delta 80.0, Basic4.report(csv.path, txt.path)
        content = File.read(txt.path)
        assert_includes content, "Ada <ada@x>: 90.0"
        assert_includes content, "Grace <grace@x>: 80.0"
        assert_includes content, "Linus <linus@x>: 70.0"
        assert_includes content, "Average: 80.00"
      end
    end
  end

  def test_report_empty_csv
    Tempfile.create(["scores", ".csv"]) do |csv|
      csv.write("name,email,score\n")
      csv.flush
      Tempfile.create(["report", ".txt"]) do |txt|
        assert_equal 0.0, Basic4.report(csv.path, txt.path)
        assert_equal "Average: 0.00\n", File.read(txt.path)
      end
    end
  end

  def test_report_missing_file
    err = assert_raises(Basic4::ReportError) do
      Basic4.report("/nonexistent/path.csv", "/tmp/out.txt")
    end
    assert_match(/input file not found/, err.message)
  end

  def test_report_missing_column
    Tempfile.create(["scores", ".csv"]) do |csv|
      csv.write("name,email\nAda,ada@x\n")
      csv.flush
      Tempfile.create(["report", ".txt"]) do |txt|
        err = assert_raises(Basic4::ReportError) { Basic4.report(csv.path, txt.path) }
        assert_match(/missing required column.*score/, err.message)
      end
    end
  end

  def test_report_invalid_score
    Tempfile.create(["scores", ".csv"]) do |csv|
      csv.write("name,email,score\nAda,ada@x,90\nGrace,grace@x,not-a-number\n")
      csv.flush
      Tempfile.create(["report", ".txt"]) do |txt|
        err = assert_raises(Basic4::ReportError) { Basic4.report(csv.path, txt.path) }
        assert_match(/row 3: invalid score "not-a-number"/, err.message)
      end
    end
  end
end
