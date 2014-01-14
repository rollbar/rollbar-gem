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
        obj.each do |k, v|
          if v.is_a?(Hash) || v.is_a?(Array)
            self.iterate_and_update(v, block)
          else
            obj[k] = block.call(v)
          end
        end
      end
    end
    
    def self.truncate(str, length)
      ellipsis = '...'
      if str.length <= length or str.length <= 3
        return str
      end
      
      str.unpack("U*").slice(0, length - ellipsis.length).pack("U*") + ellipsis
    end
  end
end