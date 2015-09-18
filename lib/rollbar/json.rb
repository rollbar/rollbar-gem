require 'rollbar/json/oj'
require 'rollbar/json/default'

module Rollbar
  module JSON
    extend self

    attr_writer :adapter_module

    def dump(object)
      MultiJson.dump(object, adapter_options)
    end

    def load(string)
      MultiJson.load(string, adapter_options)
    end

    def adapter_options
      adapter_module.options
    end

    def adapter_module
      @adapter_module ||= find_adapter_module
    end

    def find_adapter_module
      module_name = multi_json_adapter_module

      begin
        const_get(module_name)
      rescue NameError
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
    def multi_json_adapter_module
      MultiJson.current_adapter.name[/^MultiJson::Adapters::(.*)$/, 1]
    end
  end
end

