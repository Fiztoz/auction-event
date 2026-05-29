require "csv"

module Basic4
  VERSION = "0.1.0"

  def self.greet(name = "world")
    "Hello, #{name}!"
  end

  def self.parallel_greet(names)
    names
      .map { |name| Ractor.new(name) { |n| "Hello, #{n}!" } }
      .map(&:value)
  end

  class ReportError < StandardError; end

  REPORT_COLUMNS = %w[name email score].freeze

  def self.report(input_csv, output_txt)
    raise ReportError, "input file not found: #{input_csv}" unless File.exist?(input_csv)

    table =
      begin
        CSV.read(input_csv, headers: true)
      rescue CSV::MalformedCSVError => e
        raise ReportError, "malformed CSV: #{e.message}"
      end

    missing = REPORT_COLUMNS - (table.headers || [])
    raise ReportError, "missing required column(s): #{missing.join(', ')}" unless missing.empty?

    rows = table.each_with_index.map do |row, i|
      score =
        begin
          Float(row["score"])
        rescue ArgumentError, TypeError
          raise ReportError, "row #{i + 2}: invalid score #{row['score'].inspect}"
        end
      { name: row["name"], email: row["email"], score: score }
    end

    average = rows.empty? ? 0.0 : rows.sum { |r| r[:score] } / rows.size

    File.open(output_txt, "w") do |f|
      rows.each { |r| f.puts "#{r[:name]} <#{r[:email]}>: #{r[:score]}" }
      f.puts "Average: #{format('%.2f', average)}"
    end

    average
  end
end
