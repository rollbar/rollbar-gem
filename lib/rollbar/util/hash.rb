module Rollbar
  module Util
    module Hash # :nodoc:
      def self.deep_stringify_keys(hash, seen = {})
        seen.compare_by_identity
        return if seen[hash]

        seen[hash] = true
        replace_seen_children(hash, seen)

        hash.reduce({}) do |h, (key, value)|
          h[key.to_s] = map_value(value, :deep_stringify_keys, seen)

          h
        end
      end

      def self.map_value(thing, meth, seen)
        case thing
        when ::Hash
          send(meth, thing, seen)
        when Array
          if seen[thing]
            thing
          else
            seen[thing] = true
            replace_seen_children(thing, seen)
            thing.map { |v| map_value(v, meth, seen) }
          end
        else
          thing
        end
      end

      def self.replace_seen_children(thing, seen)
        case thing
        when ::Hash
          thing.keys.each do |key| # rubocop:disable Style/HashEachMethods
            if seen[thing[key]]
              thing[key] =
                "removed circular reference: #{thing[key]}"
            end
          end
        when Array
          thing.each_with_index do |_, i|
            if seen[thing[i]]
              thing[i] =
                "removed circular reference: #{thing[i]}"
            end
          end
        end
      end
    end
  end
end
