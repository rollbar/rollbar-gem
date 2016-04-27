require 'rollbar/util/hash'


module Rollbar
  module Util
    def self.iterate_and_update(obj, block)
      if obj.is_a?(Array)
        for i in 0 ... obj.size
          value = obj[i]

          if value.is_a?(::Hash) || value.is_a?(Array)
            self.iterate_and_update(value, block)
          else
            obj[i] = block.call(value)
          end
        end
      else
        key_updates = []

        obj.each do |k, v|
          new_key = nil

          if v.is_a?(::Hash) || v.is_a?(Array)
            self.iterate_and_update(v, block)
            new_key = block.call(k)
          else
            new_key = block.call(k)
            obj[k] = block.call(v)
          end

          if new_key != k
            key_updates.push([k, new_key])
          end
        end

        key_updates.each do |old_key, new_key|
          obj[new_key] = obj[old_key]
          obj.delete(old_key)
        end
      end
    end

    def self.iterate_and_update_hash(hash, block)
      hash.each do |k, v|
        if v.is_a?(::Hash)
          self.iterate_and_update_hash(v, block)
        else
          hash[k] = block.call(k, v)
        end
      end
    end

    def self.deep_copy(obj)
      if obj.is_a?(::Hash)
        result = obj.clone
        obj.each {|k, v| result[k] = deep_copy(v)}
        result
      elsif obj.is_a?(Array)
        result = obj.clone
        result.clear
        obj.each {|v| result << deep_copy(v)}
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

      if str.length <= length or str.length <= ellipsis.length
        return str
      end

      str.unpack("U*").slice(0, length - ellipsis.length).pack("U*") + ellipsis
    end

    def self.uuid_rollbar_url(data, configuration)
      "#{configuration.web_base}/instance/uuid?uuid=#{data[:uuid]}"
    end
  end
end
