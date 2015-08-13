module Rollbar
  module JSON
    extend self

    attr_accessor :backend_name
    attr_accessor :dump_method
    attr_accessor :load_method

    def load_native_json
      require 'json' unless defined?(::JSON)

      if ::JSON.respond_to?(:dump_default_options)
        options = ::JSON.dump_default_options
      else
        # Default options from json 1.1.9 up to 1.6.1
        options = { :allow_nan => true, :max_nesting => false }
      end

      self.dump_method = proc { |obj| ::JSON.generate(obj, options)  }
      self.load_method    = proc { |obj| ::JSON.load(obj) }
      self.backend_name   = :json

      true
    rescue StandardError, ScriptError => err
      Rollbar.log_debug('%p while loading JSON library: %s' % [err, err.message])
    end

    def dump(object)
      dump_method.call(object)
    end

    def load(string)
      load_method.call(string)
    end

    def setup
      load_native_json
    end
  end
end

