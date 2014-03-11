module Rollbar
  module Middleware
    module Rack
      module Builder
        include ExceptionReporter

        def call_with_rollbar(env)
          call_without_rollbar(env)
        rescue Exception => exception
          report_exception_to_rollbar(env, exception)
          raise exception
        end

        def self.included(base)
          base.send(:alias_method, :call_without_rollbar, :call)
          base.send(:alias_method, :call, :call_with_rollbar)
        end
      end
    end
  end
end
