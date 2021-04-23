Rollbar.plugins.define('sidekiq >= 3') do
  require_dependency('sidekiq')
  dependency { !configuration.disable_monkey_patch }
  dependency { defined?(Sidekiq) }
  dependency { Sidekiq::VERSION.split('.')[0].to_i >= 3 }

  execute do
    require 'rollbar/plugins/sidekiq/plugin'

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add Rollbar::Sidekiq::ResetScope
      end

      config.error_handlers << proc do |e, context|
        Rollbar::Sidekiq.handle_exception(context, e)
      end
    end
  end
end

Rollbar.plugins.define('sidekiq < 3') do
  require_dependency('sidekiq')
  dependency { !configuration.disable_monkey_patch }
  dependency { defined?(Sidekiq) }
  dependency { Sidekiq::VERSION.split('.')[0].to_i < 3 }

  execute do
    require 'rollbar/plugins/sidekiq/plugin'

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add Rollbar::Sidekiq
      end
    end
  end
end
