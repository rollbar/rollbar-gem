require 'rollbar/util'
require 'rollbar/truncation/mixin'

module Rollbar
  module Truncation
    class StringsStrategy
      include ::Rollbar::Truncation::Mixin

      STRING_THRESHOLDS = [1024, 512, 256, 128].freeze

      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        result = nil

        STRING_THRESHOLDS.each do |threshold|
          truncate_proc = truncate_strings_proc(threshold)

          ::Rollbar::Util.iterate_and_update(payload, truncate_proc)
          result = dump(payload)

          break unless truncate?(result)
        end

        result
      end

      def truncate_strings_proc(threshold)
        proc do |value|
          # Rollbar::Util.truncate will operate on characters, not bytes,
          # so use value.length, not bytesize.
          if value.is_a?(String) && value.length > threshold
            Rollbar::Util.truncate(value, threshold)
          else
            value
          end
        end
      end
    end
  end
end
