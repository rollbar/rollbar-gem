Rollbar.plugins.define('basic_socket') do
  dependency { !configuration.disable_core_monkey_patch }

  # Needed to avoid active_support (< 4.1.0) bug serializing JSONs
  dependency { defined?(ActiveSupport::VERSION::STRING) }

  execute do
    require 'socket'

    class BasicSocket
      def as_json(*)
        to_s
      end
    end
  end
end
