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
      File.expand_path('../plugins/**/*.rb', __FILE__)
    end

    def define(name, &block)
      plugin = Rollbar::Plugin.new(name)
      plugin.instance_eval(&block)

      collection << plugin
    end

    def load!
      collection.each(&:load!)
    end
  end
end
