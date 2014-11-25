require 'rollbar/util'
require 'rollbar/truncation/mixin'

module Rollbar
  module Truncation
    class StringsStrategy
      include ::Rollbar::Truncation::Mixin

      STRING_THRESHOLDS = [1024, 512, 256]

      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        result = nil

        STRING_THRESHOLDS.each do |threshold|
          new_payload = payload.clone

          ::Rollbar::Util.iterate_and_update(payload, truncate_strings_proc(threshold))
          result = dump(new_payload)

          return result unless truncate?(result)
        end

        result # Here we are just returning the last result value
      end

      def truncate_strings_proc(threshold)
        proc do |value|
          if value.is_a?(String) && value.bytesize > threshold
            Rollbar::Util.truncate(value, threshold)
          else
            value
          end
        end
      end
    end
  end
end
