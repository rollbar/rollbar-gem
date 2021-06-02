module Rollbar
  module Middleware
    module Rails
      module ShowExceptions
        include ExceptionReporter

        def render_exception_with_rollbar(env, exception)
          key = 'action_dispatch.show_detailed_exceptions'

          if exception.is_a?(ActionController::RoutingError) && env[key]
            scope = extract_scope_from(env)

            Rollbar.scoped(scope) do
              report_exception_to_rollbar(env, exception)
            end
          end

          render_exception_without_rollbar(env, exception)
        end

        def call_with_rollbar(env)
          call_without_rollbar(env)
        rescue ActionController::RoutingError => e
          # won't reach here if show_detailed_exceptions is true
          scope = extract_scope_from(env)

          Rollbar.scoped(scope) do
            report_exception_to_rollbar(env, e)
          end

          raise e
        end

        def extract_scope_from(env)
          scope = env['rollbar.scope']
          unless scope
            Rollbar.log_warn('[Rollbar] rollbar.scope key has been removed from Rack env.')
          end

          scope || {}
        end

        def self.included(base)
          base.send(:alias_method, :call_without_rollbar, :call)
          base.send(:alias_method, :call, :call_with_rollbar)

          base.send(:alias_method, :render_exception_without_rollbar, :render_exception)
          base.send(:alias_method, :render_exception, :render_exception_with_rollbar)
        end
      end
    end
  end
end
