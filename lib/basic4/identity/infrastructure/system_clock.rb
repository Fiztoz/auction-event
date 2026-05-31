require_relative "../../identity"

module Basic4::Identity::Infrastructure::SystemClock
  def self.now = Time.now.utc
end
