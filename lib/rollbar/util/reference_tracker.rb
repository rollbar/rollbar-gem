module Rollbar
  module Util
    # Tracks the containers (Hash/Array) visited while building a copy of a
    # nested structure. Used by Util::Hash.deep_stringify_keys and
    # Scrubbers::Params, which must never modify the caller's data.
    #
    # A container on the current path from the root (an ancestor) is a true
    # cycle. A container that was seen before but is not an ancestor is only
    # referenced more than once. JSON can't represent sharing, so it is copied
    # again at each occurrence. That re-copying is capped, so a deeply shared
    # graph, e.g. `x = {}; 30.times { x = { :a => x, :b => x } }`, can't make
    # the copy grow exponentially before truncation gets a chance to run.
    class ReferenceTracker
      MAX_REPEATED_REFERENCES = 10_000
      REPEATED_REFERENCE_MARKER =
        'removed repeated reference: too many repeated references'.freeze

      def initialize(max_repeated_references = MAX_REPEATED_REFERENCES)
        @ancestors = {}.compare_by_identity
        @seen = {}.compare_by_identity
        @repeats_left = max_repeated_references
      end

      def circular?(container)
        @ancestors.key?(container)
      end

      # The copy registered for an ancestor by #track.
      def copy_of(container)
        @ancestors[container]
      end

      # False once too many repeated references have been copied. Each visit
      # to a container that was already seen counts against the limit.
      def copy_allowed?(container)
        return true unless @seen.key?(container)

        (@repeats_left -= 1) >= 0
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
