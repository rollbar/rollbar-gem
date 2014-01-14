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
    
    # from http://stackoverflow.com/a/12536366/1138191
    def self.truncate(str, size)
      str = str.mb_chars.compose.to_s if str.respond_to?(:mb_chars)
      
      new_str = str.byteslice(0, size)
      
      until new_str[-1].force_encoding('utf-8').valid_encoding?
        new_str = new_str.slice(0..-2)
      end
      
      # replace last 3 characters with an ellipsis
      new_str.slice(0..-4) + '...'
    end
  end
end