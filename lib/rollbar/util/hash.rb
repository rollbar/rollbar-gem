module Rollbar
  module Util
    module Hash
      def self.deep_stringify_keys(hash)
        hash.reduce({}) do |h, (key, value)|
          h[key.to_s] = map_value(value, :deep_stringify_keys)

          h
        end
      end

      def self.map_value(thing, m)
        case thing
        when ::Hash
          send(m, thing)
        when Array
          thing.map { |v| map_value(v, m) }
        else
          thing
        end
      end
    end
  end
end
