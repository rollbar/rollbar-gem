require 'multi_json'
require 'rollbar/json/oj'
require 'rollbar/json/default'
require 'rollbar/language_support'

begin
  require 'oj'
rescue LoadError
end

module Rollbar
  module JSON # :nodoc:
    extend self

    attr_writer :options_module

    def dump(object)
      # `basic_socket` plugin addresses the following issue: https://github.com/rollbar/rollbar-gem/issues/845
      Rollbar.plugins.get('basic_socket').load_scoped!(true) do
        with_adapter { MultiJson.dump(object, adapter_options) }
      end
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

      if LanguageSupport.const_defined?(Rollbar::JSON, module_name, false)
        LanguageSupport.const_get(Rollbar::JSON, module_name, false)
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
      detect_multi_json_adapter.name[/^MultiJson::Adapters::(.*)$/, 1]
    end
  end
end
