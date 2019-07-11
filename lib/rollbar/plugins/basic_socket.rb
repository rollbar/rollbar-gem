Rollbar.plugins.define('basic_socket') do
  load_on_demand

  dependency { !configuration.disable_core_monkey_patch }

  # Needed to avoid active_support (< 4.1.0) bug serializing JSONs
  dependency do
    defined?(ActiveSupport::VERSION::STRING) &&
      Gem::Version.new(ActiveSupport::VERSION::STRING) < Gem::Version.new('4.1.0')
  end

  execute do
    class BasicSocket # :nodoc:
      def new_as_json(_options = nil)
        {
          :value => inspect
        }
      end
      # alias_method is recommended over alias when aliasing at runtime.
      # https://github.com/rubocop-hq/ruby-style-guide#alias-method
      alias_method :original_as_json, :as_json # rubocop:disable Style/Alias
      alias_method :as_json, :new_as_json # rubocop:disable Style/Alias
    end
  end

  revert do
    class BasicSocket # :nodoc:
      alias_method :as_json, :original_as_json # rubocop:disable Style/Alias
    end
  end
end
