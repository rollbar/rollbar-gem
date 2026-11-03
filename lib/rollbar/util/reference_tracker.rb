module Rollbar
  module Util
    # Tracks the containers (Hash/Array) visited while building a copy of a
    # nested structure. Used by Util::Hash.deep_stringify_keys and
    # Scrubbers::Params, which must never modify the caller's data.
    #
    # A container on the current path from the root (an ancestor) is a true
    # cycle. A container that was seen before but is not an ancestor is only
    # referenced more than once. JSON can't represent sharing, so it is copied
    # again at each occurrence. That re-copying is capped by the number of
    # entries (hash pairs and array elements) it copies, so neither a deeply
    # shared graph, e.g. `x = {}; 30.times { x = { :a => x, :b => x } }`, nor a
    # wide hash referenced many times can make the copy grow far beyond the
    # input before truncation gets a chance to run. At around 10 bytes of JSON
    # each, 50,000 entries already fill the 512 KB payload limit.
    class ReferenceTracker
      MAX_REPEATED_ENTRIES = 50_000
      REPEATED_REFERENCE_MARKER =
        'removed repeated reference: too many repeated references'.freeze

      def initialize(max_repeated_entries = MAX_REPEATED_ENTRIES)
        @ancestors = {}.compare_by_identity
        @seen = {}.compare_by_identity
        @entries_left = max_repeated_entries
      end

      def circular?(container)
        @ancestors.key?(container)
      end

      # The copy registered for an ancestor by #track.
      def copy_of(container)
        @ancestors[container]
      end

      # False if copying the `size` entries of a container that was already
      # seen would go over the limit. A container seen for the first time is
      # never charged, so the entries copied in total are bounded by the size
      # of the input plus the limit, whatever the shape of the sharing.
      def copy_allowed?(container, size)
        return true unless @seen.key?(container)
        return false if size > @entries_left

        @entries_left -= size
        true
      end

      # Marks `container` as an ancestor, mapped to `copy`, while the block
      # builds its copy.
      def track(container, copy = nil)
        @seen[container] = true
        @ancestors[container] = copy
        yield
      ensure
        @ancestors.delete(container)
      end
    end
  end
end
