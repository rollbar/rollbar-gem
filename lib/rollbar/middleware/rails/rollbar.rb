require 'rollbar/request_data_extractor'
require 'rollbar/exception_reporter'

module Rollbar
  module Middleware
    module Rails
      class RollbarMiddleware
        include RequestDataExtractor
        include ExceptionReporter

        def initialize(app)
          @app = app
        end

        def call(env)
          Rollbar.reset_notifier!

          env['rollbar.scope'] = scope = fetch_scope(env)

          Rollbar.scoped(scope) do
            begin
              response = @app.call(env)

              if (framework_exception = env['action_dispatch.exception'])
                report_exception_to_rollbar(env, framework_exception)
              end

              response
            rescue Exception => exception
              report_exception_to_rollbar(env, exception)
              raise
            end
          end
        end

        def fetch_scope(env)
          request_data = extract_request_data_from_rack(env)

          # Scope a new notifier with request data and a Proc for person data
          # for any reports that happen while a controller is handling a request
          {
            :request => request_data,
            :person => person_data_proc(env),
            :context => context(request_data)
          }
        end

        def person_data_proc(env)
          block = proc { extract_person_data_from_controller(env) }
          return block unless defined?(ActiveRecord::Base)

          proc { ActiveRecord::Base.connection_pool.with_connection(&block) }
        end

        def context(request_data)
          return unless request_data[:route]

          route = request_data[:route]
          # make sure route is a hash built by RequestDataExtractor
          return "#{route[:controller]}" + '#' + "#{route[:action]}" if route.is_a?(Hash) && !route.empty?
        end
      end
    end
  end
end
