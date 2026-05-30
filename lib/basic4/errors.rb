module Basic4
  class ValidationError < StandardError
    attr_reader :field

    def initialize(field, message)
      @field = field
      super(message)
    end
  end
end
