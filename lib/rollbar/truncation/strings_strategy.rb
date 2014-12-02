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
        new_payload = payload.clone

        STRING_THRESHOLDS.each do |threshold|
          truncate_proc = truncate_strings_proc(threshold)

          ::Rollbar::Util.iterate_and_update(new_payload, truncate_proc)
          result = dump(new_payload)

          break unless truncate?(result)
        end

        result
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
