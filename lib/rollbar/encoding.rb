require 'rollbar/encoding/encoder'

module Rollbar
  module Encoding
    def self.encode(object)
      can_be_encoded = object.is_a?(Symbol) || object.is_a?(String)

      return object unless can_be_encoded

      Encoder.new(object).encode
    end
  end
end
