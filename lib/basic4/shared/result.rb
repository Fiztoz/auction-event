require_relative "shared"

module Basic4::Result
  module Chain
    def bind
      success? ? yield(value) : self
    end

    def map
      success? ? Success.new(value: yield(value)) : self
    end

    def tap_ok
      yield(value) if success?
      self
    end

    def success?
      is_a?(Success)
    end

    def failure?
      is_a?(Failure)
    end
  end

  Success = Data.define(:value)           { include Chain }
  Failure = Data.define(:field, :message) { include Chain }

  module_function

  def success(value)
    Success.new(value: value)
  end

  def failure(field, message)
    Failure.new(field: field, message: message)
  end
end
