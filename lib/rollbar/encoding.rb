module Rollbar
  module Encoding
    class << self
      attr_accessor :encoding_class
    end

    def self.setup
      require 'rollbar/encoding/encoder'
      self.encoding_class = Rollbar::Encoding::Encoder
    end

    def self.encode(object)
      can_be_encoded = object.is_a?(String) || object.is_a?(Symbol)

      return object unless can_be_encoded

      encoding_class.new(object).encode
    end
  end
end

Rollbar::Encoding.setup
