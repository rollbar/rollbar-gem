require 'rollbar/util/hash'

module Rollbar
  module Util # :nodoc:
    def self.iterate_and_update(obj, block, seen = {})
      return if obj.frozen? || seen[obj.object_id]

      seen[obj.object_id] = true

      if obj.is_a?(Array)
        iterate_and_update_array(obj, block, seen)
      else
        iterate_and_update_hash(obj, block, seen)
      end
    end

    def self.iterate_and_update_array(array, block, seen)
      array.each_with_index do |value, i|
        if value.is_a?(::Hash) || value.is_a?(Array)
          iterate_and_update(value, block, seen)
        else
          array[i] = block.call(value)
        end
      end
    end

    def self.iterate_and_update_hash(obj, block, seen)
      obj.keys.each do |k|
        v = obj[k]
        new_key = block.call(k)

        if v.is_a?(::Hash) || v.is_a?(Array)
          iterate_and_update(v, block, seen)
        else
          obj[k] = block.call(v)
        end

        if new_key != k
          obj[new_key] = obj[k]
          obj.delete(k)
        end
      end
    end

    def self.deep_copy(obj)
      if obj.is_a?(::Hash)
        result = obj.clone
        obj.each { |k, v| result[k] = deep_copy(v)}
        result
      elsif obj.is_a?(Array)
        result = obj.clone
        result.clear
        obj.each { |v| result << deep_copy(v)}
        result
      else
        obj
      end
    end

    def self.deep_merge(hash1, hash2)
      hash1 ||= {}
      hash2 ||= {}

      hash2.each_key do |k|
        if hash1[k].is_a?(::Hash) && hash2[k].is_a?(::Hash)
          hash1[k] = deep_merge(hash1[k], hash2[k])
        elsif hash1[k].is_a?(Array) && hash2[k].is_a?(Array)
          hash1[k] += deep_copy(hash2[k])
        elsif hash2[k]
          hash1[k] = deep_copy(hash2[k])
        end
      end

      hash1
    end

    def self.truncate(str, length)
      ellipsis = '...'

      return str if str.length <= length || str.length <= ellipsis.length

      str.unpack('U*').slice(0, length - ellipsis.length).pack('U*') + ellipsis
    end

    def self.uuid_rollbar_url(data, configuration)
      "#{configuration.web_base}/instance/uuid?uuid=#{data[:uuid]}"
    end

    def self.enforce_valid_utf8(payload)
      normalizer = lambda { |object| Encoding.encode(object) }

      Util.iterate_and_update(payload, normalizer)
    end
  end
end
