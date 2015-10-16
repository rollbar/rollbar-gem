require 'multi_json'
require 'rollbar/json/oj'
require 'rollbar/json/default'

begin
  require 'oj'
rescue LoadError
end

module Rollbar
  module JSON
    extend self

    attr_writer :options_module

    def dump(object)
      with_adapter { MultiJson.dump(object, adapter_options) }
    end

    def load(string)
      with_adapter { MultiJson.load(string, adapter_options) }
    end

    def with_adapter(&block)
      MultiJson.with_adapter(detect_multi_json_adapter, &block)
    end

    def detect_multi_json_adapter
      options = {}
      options[:adapter] = :oj if defined?(::Oj)

      MultiJson.current_adapter(options)
    end

    def adapter_options
      options_module.options
    end

    def options_module
      @options_module ||= find_options_module
    end

    def find_options_module
      module_name = multi_json_adapter_module_name

      if Rollbar::JSON.const_defined?(module_name, false)
        Rollbar::JSON.const_get(module_name, false)
      else
        Default
      end
    end

    # MultiJson adapters have this name structure:
    # "MultiJson::Adapters::{AdapterModule}"
    #
    # Ex: MultiJson::Adapters::Oj
    # Ex: MultiJson::Adapters::JsonGem
    #
    # In this method we just get the last module name.
    def multi_json_adapter_module_name
      MultiJson.current_adapter.name[/^MultiJson::Adapters::(.*)$/, 1]
    end
  end
end

