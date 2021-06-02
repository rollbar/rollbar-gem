module Rollbar
  module Util
    module Hash # :nodoc:
      def self.deep_stringify_keys(hash, seen = {})
        return if seen[hash.object_id]

        seen[hash.object_id] = true
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
          if seen[thing.object_id]
            thing
          else
            seen[thing.object_id] = true
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
          thing.keys.each do |key|
            if seen[thing[key].object_id]
              thing[key] =
                "removed circular reference: #{thing[key]}"
            end
          end
        when Array
          thing.each_with_index do |_, i|
            if seen[thing[i].object_id]
              thing[i] =
                "removed circular reference: #{thing[i]}"
            end
          end
        end
      end
    end
  end
end
