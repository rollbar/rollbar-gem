module Rollbar
  # Represents a plugin in the gem. Every plugin can have multiple dependencies
  # and multiple execution blocks.
  # On Rollbar initialization, all plugins will be saved in memory and those that
  # satisfy the dependencies will be loaded
  class Plugin
    attr_reader :name
    attr_reader :dependencies
    attr_reader :callables
    attr_accessor :loaded

    private :loaded=

    def initialize(name)
      @name = name
      @dependencies = []
      @callables = []
      @loaded = false
    end

    def configuration
      Rollbar.configuration
    end

    def load!
      return unless load?

      begin
        callables.each(&:call)
      rescue => e
        log_loading_error(e)
      ensure
        self.loaded = true
      end
    end

    def execute(&block)
      callables << block
    end

    def execute!(&block)
      block.call if load?
    end

    private

    def dependency(&block)
      dependencies << block
    end

    def load?
      !loaded && dependencies.all?(&:call)
    rescue => e
      log_loading_error(e)

      false
    end

    def log_loading_error(e)
      Rollbar.log_error("Error trying to load plugin '#{name}': #{e.class}, #{e.message}")
    end
  end
end
