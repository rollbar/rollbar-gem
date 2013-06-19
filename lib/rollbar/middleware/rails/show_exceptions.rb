module Rollbar
  module Middleware
    module Rails
      module ShowExceptions
        include ExceptionReporter

        def render_exception_with_rollbar(env, exception)
          key = 'action_dispatch.show_detailed_exceptions'
          
          # don't report production exceptions here as it is done below
          # in call_with_rollbar() when show_detailed_exception is false
          if not env.has_key?(key) or env[key]
            report_exception_to_rollbar(env, exception)
          end
          render_exception_without_rollbar(env, exception)
        end
        
        def call_with_rollbar(env)
          call_without_rollbar(env)
        rescue => exception
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
