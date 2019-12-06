module RollbarErrorContext
  attr_accessor :rollbar_context
end

Rollbar.plugins.define('error_context') do
  dependency { configuration.enable_error_context }

  execute! do
    StandardError.send(:include, RollbarErrorContext)
  end
end
