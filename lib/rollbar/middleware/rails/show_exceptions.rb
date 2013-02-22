module Rollbar
  module Middleware
    module Rails
      module ShowExceptions
        include ExceptionReporter

        def render_exception_with_rollbar(env, exception)
          report_exception_to_rollbar(env, exception)
          render_exception_without_rollbar(env, exception)
        end

        def call_with_rollbar(env)
          call_without_rollbar(env)
        rescue => exception
          report_exception_to_rollbar(env, exception)
          raise exception
        end

        def self.included(base)
          base.send(:alias_method_chain, :render_exception, :rollbar)
          base.send(:alias_method_chain, :call, :rollbar)
        end
      end
    end
  end
end
