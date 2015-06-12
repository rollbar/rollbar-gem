require 'rollbar/encoding/encoder' unless RUBY_VERSION.start_with?('1.8')
require 'rollbar/encoding/legacy_encoder' if RUBY_VERSION.start_with?('1.8')

module Rollbar
  module Encoding
    def self.encode(object)
      can_be_encoded = object.is_a?(Symbol) || object.is_a?(String)

      return object unless can_be_encoded

      encoding_class.new(object).encode
    end

    def self.encoding_class
      if String.instance_methods.include?(:encode)
        Encoder
      else
        LegacyEncoder
      end
    end
  end
end
