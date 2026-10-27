Rollbar.plugins.define('action_cable') do
  dependency { !configuration.disable_monkey_patch }
  dependency { !configuration.disable_action_cable_monkey_patch }
  dependency { defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load) }

  execute do
    # Rails >= 6.0 runs this hook once ActionCable::Connection::Base is loaded,
    # or straight away if it already is. Require the patch only then: it pulls
    # in Rack, which non-Rails apps that just use ActiveSupport may not have.
    ActiveSupport.on_load(:action_cable_connection) do
      require 'rollbar/plugins/action_cable/plugin'
      Rollbar::ActionCable.patch!
    end
  end
end
