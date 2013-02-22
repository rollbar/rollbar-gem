module Rollbar
  module Middleware
    module Rack
      module TestSession
        include ExceptionReporter

        def process_request_with_rollbar(uri, env, &block)
          process_request_without_rollbar(uri, env, &block)
        rescue => exception
          report_exception_to_rollbar(env, exception)
          raise exception
        end

        def env_for_with_rollbar(path, env)
          env_for_without_rollbar(path, env)
        rescue => exception
          report_exception_to_rollbar(env, exception)
          raise exception
        end

        def self.included(base)
          base.send(:alias_method, :process_request_without_rollbar, :process_request)
          base.send(:alias_method, :process_request, :process_request_with_rollbar)

          base.send(:alias_method, :env_for_without_rollbar, :env_for)
          base.send(:alias_method, :env_for, :env_for_with_rollbar)
        end
      end
    end
  end
end
