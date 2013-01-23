if defined?(Rack::Builder)
  require 'ratchetio/middleware/rack/builder'
  Rack::Builder.send(:include, Ratchetio::Middleware::Rack::Builder)
end

if defined?(Rack::Test::Session)
  require 'ratchetio/middleware/rack/test_session'
  Rack::Test::Session.send(:include, Ratchetio::Middleware::Rack::TestSession)
end
