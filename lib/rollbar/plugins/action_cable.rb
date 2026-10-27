Rollbar.plugins.define('action_cable') do
  dependency { !configuration.disable_monkey_patch }
  dependency { !configuration.disable_action_cable_monkey_patch }
  dependency { defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load) }

  execute do
    require 'rollbar/plugins/action_cable/plugin'

    # Rails >= 6.0 runs this hook once ActionCable::Connection::Base is loaded,
    # or straight away if it already is.
    ActiveSupport.on_load(:action_cable_connection) do
      Rollbar::ActionCable.patch!
    end
  end
end
