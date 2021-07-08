require 'rollbar/language_support'
require 'json'

module Rollbar
  module JSON # :nodoc:
    module_function

    attr_writer :options_module

    def dump(object)
      Rollbar.plugins.get('basic_socket').load_scoped!(true) do
        ::JSON.generate(object)
      end
    end

    def load(string)
      ::JSON.parse(string)
    end
  end
end
