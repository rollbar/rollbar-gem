require 'iconv'

module Rollbar
  module Encoding
    class LegacyEncoder
      attr_accessor :object

      def initialize(object)
        @object = object
      end

      def encode
        value = object.to_s
        encoded_value = ::Iconv.conv('UTF-8//IGNORE', 'UTF-8', value)

        object.is_a?(Symbol) ? encoded_value.to_sym : encoded_value
      end
    end
  end
end
