Rollbar.plugins.define('delayed_job') do
  dependency { !configuration.disable_monkey_patch }
  dependency do
    defined?(Delayed) && defined?(Delayed::Worker) && configuration.delayed_job_enabled
  end

  execute do
    require 'rollbar/plugins/delayed_job/plugin'

    Rollbar::Delayed.wrap_worker
  end
end
