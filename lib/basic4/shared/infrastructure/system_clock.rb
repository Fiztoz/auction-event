require_relative "../shared"

module Basic4::Infrastructure::SystemClock
  def self.now = Time.now.utc
end
