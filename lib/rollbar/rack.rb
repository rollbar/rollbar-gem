if defined?(Rack::Builder)
  require 'rollbar/middleware/rack/builder'
  Rack::Builder.send(:include, Rollbar::Middleware::Rack::Builder)
end

if defined?(Rack::Test::Session)
  require 'rollbar/middleware/rack/test_session'
  Rack::Test::Session.send(:include, Rollbar::Middleware::Rack::TestSession)
end
