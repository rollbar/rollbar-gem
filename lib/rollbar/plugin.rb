module Rollbar
  # Represents a plugin in the gem. Every plugin can have multiple dependencies
  # and multiple execution blocks.
  # On Rollbar initialization, all plugins will be saved in memory and those that
  # satisfy the dependencies will be loaded
  class Plugin
    attr_reader :name
    attr_reader :dependencies
    attr_reader :callables
    attr_reader :revert_callables
    attr_accessor :on_demand
    attr_accessor :loaded

    private :loaded=

    def initialize(name)
      @name = name
      @dependencies = []
      @callables = []
      @revert_callables = []
      @loaded = false
      @on_demand = false
    end

    def load_on_demand
      @on_demand = true
    end

    def configuration
      Rollbar.configuration
    end

    def load_scoped!(transparent = false)
      if transparent
        load! unless load?

        result = yield

        unload! if loaded
      else
        return unless load?

        load!

        result = yield

        unload!
      end

      result
    end

    def load!
      return unless load?

      begin
        callables.each(&:call)
      rescue StandardError => e
        log_loading_error(e)
      ensure
        self.loaded = true
      end
    end

    def unload!
      return unless loaded

      begin
        revert_callables.each(&:call)
      rescue StandardError => e
        log_loading_error(e)
      ensure
        self.loaded = false
      end
    end

    def execute(&block)
      callables << block
    end

    def execute!
      yield if load?
    end

    def revert(&block)
      revert_callables << block
    end

    private

    def dependency(&block)
      dependencies << block
    end

    def require_dependency(file)
      dependency do
        begin
          require file
          true
        rescue LoadError
          false
        end
      end
    end

    def load?
      !loaded && dependencies_satisfy?
    rescue StandardError => e
      log_loading_error(e)

      false
    end

    def dependencies_satisfy?
      dependencies.all?(&:call)
    end

    def log_loading_error(error)
      Rollbar.log_error("Error trying to load plugin '#{name}': #{error.class}, #{error.message}")
    end
  end
end
