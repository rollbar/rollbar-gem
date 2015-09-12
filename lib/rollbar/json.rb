module Rollbar
  module JSON
    extend self

    attr_accessor :backend_name
    attr_accessor :load_method

    def load_native_json
      require 'json' unless defined?(::JSON)

      self.load_method    = proc { |obj| ::JSON.load(obj) }
      self.backend_name   = :json

      true
    rescue StandardError, ScriptError => err
      Rollbar.log_debug('%p while loading JSON library: %s' % [err, err.message])
    end

    def dump(object)
      # JSON.generate defined above returnes a NoMethodError for key?, needs to be changed to to_json instead
      object.to_json
    end

    def load(string)
      load_method.call(string)
    end

    def setup
      load_native_json
    end
  end
end

