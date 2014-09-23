require 'rollbar'
require 'rollbar/exception_reporter'

module Rollbar
  module Middleware
    class Sinatra
      include ::Rollbar::ExceptionReporter

      def initialize(app)
        @app = app
      end

      def call(env)
        response = @app.call(env)
        report_exception_to_rollbar(env, framework_error(env)) if framework_error(env)
        response
      rescue ::Exception => exception
        report_exception_to_rollbar(env, exception)
        raise
      end

      def framework_error(env)
        env['sinatra.error']
      end
    end
  end
end
