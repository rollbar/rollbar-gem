module Rollbar
  module Middleware
    module Rails
      class RollbarMiddleware
        include RequestDataExtractor
        include ExceptionReporter

        def initialize(app)
          @app = app
        end

        def person_data_proc(env)
          proc do
            ActiveRecord::Base.connection_pool.with_connection do
              extract_person_data_from_controller(env)
            end
          end
        end

        def context(request_data)
          return unless request_data[:route]

          route = request_data[:route]
          # make sure route is a hash built by RequestDataExtractor
          return "#{route[:controller]}" + '#' + "#{route[:action]}" if route.is_a?(Hash) && !route.empty?
        end

        def call(env)
          begin
            request_data = extract_request_data_from_rack(env)

            # Scope a new notifier with request data and a Proc for person data
            # for any reports that happen while a controller is handling a request
            rollbar_scope = {
              :request => request_data,
              :person => person_data_proc(env),
              :context => context(request_data)
            }

            response = Rollbar.scoped(rollbar_scope) { @app.call(env) }
          rescue Exception => exception
            report_exception_to_rollbar(env, exception)
            Rollbar.reset_notifier!

            raise
          end

          report_exception_to_rollbar(env, env["rack.exception"]) if env["rack.exception"]

          Rollbar.reset_notifier!

          response
        end
      end
    end
  end
end
