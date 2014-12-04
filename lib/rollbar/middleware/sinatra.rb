require 'rollbar'
require 'rollbar/exception_reporter'
require 'rollbar/request_data_extractor'

module Rollbar
  module Middleware
    class Sinatra
      include ::Rollbar::ExceptionReporter
      include RequestDataExtractor

      def initialize(app)
        @app = app
      end

      def call(env)
        Rollbar.reset_notifier!

        Rollbar.scoped(fetch_scope(env)) do
          begin
            response = @app.call(env)
            report_exception_to_rollbar(env, framework_error(env)) if framework_error(env)
            response
          rescue Exception => e
            report_exception_to_rollbar(env, e)
            raise
          end
        end
      end

      def fetch_scope(env)
        request_data = extract_request_data_from_rack(env)
        {
          :request => request_data,
          :person => extract_person_data_from_controller(env)
        }
      rescue Exception => e
        report_exception_to_rollbar(env, e)
        raise
      end

      def framework_error(env)
        env['sinatra.error']
      end
    end
  end
end
