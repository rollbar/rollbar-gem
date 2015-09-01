module Rollbar
  module Encoding
    class << self
      attr_accessor :encoding_class
    end

    def self.encode(object)
      can_be_encoded = object.is_a?(String) || object.is_a?(Symbol)

      return object unless can_be_encoded

      encoding_class.new(object).encode
    end
  end
end

if String.instance_methods.include?(:encode)
  require 'rollbar/encoding/encoder'
  Rollbar::Encoding.encoding_class = Rollbar::Encoding::Encoder
else
  require 'rollbar/encoding/legacy_encoder'
  Rollbar::Encoding.encoding_class = Rollbar::Encoding::LegacyEncoder
end

