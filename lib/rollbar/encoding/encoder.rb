module Rollbar
  module Encoding
    class Encoder
      ALL_ENCODINGS = [::Encoding::UTF_8, ::Encoding::ISO_8859_1, ::Encoding::ASCII_8BIT, ::Encoding::US_ASCII]
      ASCII_ENCODINGS = [::Encoding::US_ASCII, ::Encoding::ASCII_8BIT, ::Encoding::ISO_8859_1]
      ENCODING_OPTIONS = { :invalid => :replace, :undef => :replace, :replace => '' }
      UTF8 = 'UTF-8'.freeze
      BINARY = 'binary'.freeze

      attr_accessor :object

      def initialize(object)
        @object = object
      end

      def encode
        value = object.to_s
        encoding = value.encoding

        # This will be most of cases so avoid force anything for them
        if encoding == ::Encoding::UTF_8 && value.valid_encoding?
          encoded_value = value
        else
          encoded_value = force_encoding(value).encode(*encoding_args(value))
        end

        object.is_a?(Symbol) ? encoded_value.to_sym : encoded_value
      end

      private

      def force_encoding(value)
        return value if value.frozen?

        value.force_encoding(detect_encoding(value)) if value.encoding == ::Encoding::UTF_8

        value
      end

      def detect_encoding(v)
        value = v.dup

        ALL_ENCODINGS.detect do |encoding|
          begin
            value.force_encoding(encoding).encode(::Encoding::UTF_8).codepoints
            true
          rescue
            false
          end
        end
      end

      def encoding_args(value)
        args = [UTF8]
        args << BINARY if ASCII_ENCODINGS.include?(value.encoding)
        args << ENCODING_OPTIONS

        args
      end
    end
  end
end
