module Rollbar
  module JSON
    extend self

    attr_accessor :backend_name
    attr_accessor :dump_method
    attr_accessor :load_method

    def load_oj
      require 'oj'

      options = { :mode=> :compat,
                  :use_to_json => false,
                  :symbol_keys => false,
                  :circular => false
                }

      self.dump_method = proc { |obj| Oj.dump(obj, options) }
      self.load_method = proc { |obj| Oj.load(obj, options) }
      self.backend_name = :oj

      true
    end

    def dump(object)
      # JSON.generate defined above returnes a NoMethodError for key? for some activerecord definitions
      begin
        dump_method.call(object)
      rescue => e
        # If exception caught, try to_json 
        result = object.try(:to_json)
        if result.nil?
          raise e
        else
          result
        end
      end
    end

    def load(string)
      load_method.call(string)
    end

    def setup
      load_oj
    end
  end
end

