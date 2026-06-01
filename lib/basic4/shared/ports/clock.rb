require_relative "../shared"

# Time port — abstracts "now" so domain logic can be tested
# without freezing real time.
# Required: now -> Time (UTC)
module Basic4::Ports::Clock; end
