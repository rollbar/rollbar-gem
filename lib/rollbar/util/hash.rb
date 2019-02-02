module Rollbar
  module Util
    module Hash # :nodoc:
      def self.deep_stringify_keys(hash, seen = {})
        return if seen[hash.object_id]

        seen[hash.object_id] = true

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
            thing.map { |v| map_value(v, meth, seen) }
          end
        else
          thing
        end
      end
    end
  end
end
