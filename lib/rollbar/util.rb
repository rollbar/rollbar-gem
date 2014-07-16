module Rollbar
  module Util
    def self.iterate_and_update(obj, block)
      if obj.is_a?(Array)
        for i in 0 ... obj.size
          value = obj[i]
          
          if value.is_a?(Hash) || value.is_a?(Array)
            self.iterate_and_update(value, block)
          else
            obj[i] = block.call(value)
          end
        end
      else
        key_updates = []
        
        obj.each do |k, v|
          new_key = nil
          
          if v.is_a?(Hash) || v.is_a?(Array)
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
    
    def self.truncate(str, length)
      ellipsis = '...'
      
      if str.length <= length or str.length <= ellipsis.length
        return str
      end
      
      str.unpack("U*").slice(0, length - ellipsis.length).pack("U*") + ellipsis
    end
  end
end
