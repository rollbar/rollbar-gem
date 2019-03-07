Rollbar.plugins.define('basic_socket') do
  load_on_demand

  dependency { !configuration.disable_core_monkey_patch }

  # Needed to avoid active_support (< 4.1.0) bug serializing JSONs
  dependency do
    defined?(ActiveSupport::VERSION::STRING) &&
      Gem::Version.new(ActiveSupport::VERSION::STRING) < Gem::Version.new('5.2.0')
  end

  @original_as_json = ::BasicSocket.public_instance_method(:as_json)

  execute do
    require 'socket'

    class BasicSocket # :nodoc:
      def as_json(_options = nil)
        {
          :value => inspect
        }.to_json
      end
    end
  end

  revert do
    ::BasicSocket.define_method(:as_json, @original_as_json)
  end
end
