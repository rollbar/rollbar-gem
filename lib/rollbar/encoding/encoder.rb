module Rollbar
  module Encoding
    class Encoder
      ALL_ENCODINGS = [::Encoding::UTF_8, ::Encoding::ISO_8859_1, ::Encoding::ASCII_8BIT, ::Encoding::US_ASCII].freeze
      ASCII_ENCODINGS = [::Encoding::US_ASCII, ::Encoding::ASCII_8BIT, ::Encoding::ISO_8859_1].freeze
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
        encoded_value = if encoding == ::Encoding::UTF_8 && value.valid_encoding?
                          value
                        else
                          force_encoding(value).encode(
                            *encoding_args(value),
                            # Ruby 2.7 requires this to look like keyword args,
                            # and Ruby 1.9.3 doesn't understand keyword args, so
                            # don't use hash rockets here and both will be happy.
                            invalid: :replace, undef: :replace, replace: '' # rubocop:disable Style/HashSyntax
                          )
                        end

        object.is_a?(Symbol) ? encoded_value.to_sym : encoded_value
      rescue StandardError => e
        # If encoding fails for any reason, replace the string with a diagnostic error.
        "error encoding string: #{e.class}: #{e.message}"
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
            # Seems #codepoints is faster than #valid_encoding?
            value.force_encoding(encoding).encode(::Encoding::UTF_8).codepoints
            true
          rescue StandardError
            false
          end
        end
      end

      def encoding_args(value)
        args = [UTF8]
        args << BINARY if ASCII_ENCODINGS.include?(value.encoding)

        args
      end
    end
  end
end
