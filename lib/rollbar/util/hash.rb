module Rollbar
  module Util
    module Hash # :nodoc:
      # Returns a copy of `hash` with all keys converted to strings. The input
      # is never modified.
      #
      # `ancestors` holds the containers on the path from the root to the
      # current node, so only true cycles are replaced. An object that is merely
      # referenced more than once (e.g. the same hash under two keys) is not
      # circular and is copied at each occurrence.
      def self.deep_stringify_keys(hash, ancestors = {})
        ancestors.compare_by_identity
        ancestors[hash] = true

        hash.reduce({}) do |h, (key, value)|
          h[key.to_s] = map_value(value, :deep_stringify_keys, ancestors)

          h
        end
      ensure
        ancestors.delete(hash)
      end

      def self.map_value(thing, meth, ancestors)
        return thing unless thing.is_a?(::Hash) || thing.is_a?(Array)
        return "removed circular reference: #{thing}" if ancestors[thing]
        return send(meth, thing, ancestors) if thing.is_a?(::Hash)

        begin
          ancestors[thing] = true
          thing.map { |v| map_value(v, meth, ancestors) }
        ensure
          ancestors.delete(thing)
        end
      end
    end
  end
end
