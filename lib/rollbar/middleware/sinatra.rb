require 'rollbar/middleware/rack'

module Rollbar
  module Middleware
    class Sinatra < Rollbar::Middleware::Rack
      def framework_error(env)
        env['sinatra.error']
      end
    end
  end
end
