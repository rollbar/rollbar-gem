require 'rollbar/util/reference_tracker'

module Rollbar
  module Util
    module Hash # :nodoc:
      # Returns a copy of `hash` with all keys converted to strings. The input
      # is never modified.
      #
      # Only true cycles are replaced. An object that is merely referenced more
      # than once (e.g. the same hash under two keys) is not circular and is
      # copied at each occurrence, up to the limit in ReferenceTracker.
      def self.deep_stringify_keys(hash, tracker = ReferenceTracker.new)
        tracker.track(hash) do
          hash.reduce({}) do |h, (key, value)|
            h[key.to_s] = map_value(value, :deep_stringify_keys, tracker)

            h
          end
        end
      end

      def self.map_value(thing, meth, tracker)
        return thing unless thing.is_a?(::Hash) || thing.is_a?(Array)
        return "removed circular reference: #{thing}" if tracker.circular?(thing)
        unless tracker.copy_allowed?(thing)
          return ReferenceTracker::REPEATED_REFERENCE_MARKER
        end
        return send(meth, thing, tracker) if thing.is_a?(::Hash)

        tracker.track(thing) { thing.map { |v| map_value(v, meth, tracker) } }
      end
    end
  end
end
