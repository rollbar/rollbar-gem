require 'rollbar/plugin'

module Rollbar
  # Stores the available plugin definitions and loads them
  class Plugins
    attr_reader :collection

    def initialize
      @collection = []
    end

    def require_all
      Dir.glob(plugin_files).each do |file|
        require file.to_s
      end
    end

    def plugin_files
      File.expand_path('../plugins/*.rb', __FILE__)
    end

    def define(name, &block)
      return if loaded?(name)

      plugin = Rollbar::Plugin.new(name)
      collection << plugin

      plugin.instance_eval(&block)
    end

    def load!
      collection.each(&:load!)
    end

    private

    def loaded?(name)
      collection.any? { |plugin| plugin.name == name }
    end
  end
end
