module Rollbar
  module Middleware
    module Rails
      module ShowExceptions
        include ExceptionReporter

        def render_exception_with_rollbar(env, exception)
          key = 'action_dispatch.show_detailed_exceptions'
          if exception.is_a? ActionController::RoutingError and env[key]
            report_exception_to_rollbar(env, exception)
          end
          
          render_exception_without_rollbar(env, exception)
        end

        def call_with_rollbar(env)
          call_without_rollbar(env)
        rescue ActionController::RoutingError => exception
          # won't reach here if show_detailed_exceptions is true
          report_exception_to_rollbar(env, exception)
          raise exception
        end

        def self.included(base)
          base.send(:alias_method_chain, :call, :rollbar)
          base.send(:alias_method_chain, :render_exception, :rollbar)
        end
      end
    end
  end
end
