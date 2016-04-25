Rollbar.plugins.define('rack') do
  dependency { !configuration.disable_monkey_patch }
  dependency { !configuration.disable_rack_monkey_patch }

  execute do
    if defined?(Rack::Builder)
      require 'rollbar/middleware/rack/builder'
      Rack::Builder.send(:include, Rollbar::Middleware::Rack::Builder)
    end

    if defined?(Rack::Test::Session)
      require 'rollbar/middleware/rack/test_session'
      Rack::Test::Session.send(:include, Rollbar::Middleware::Rack::TestSession)
    end
  end
end
