module Rollbar
  module Middleware
    class Rack
      module TestSession
        include ExceptionReporter

        def env_for_with_rollbar(path, env)
          env_for_without_rollbar(path, env)
        rescue Exception => e
          report_exception_to_rollbar(env, e)
          raise e
        end

        def self.included(base)
          base.send(:alias_method, :env_for_without_rollbar, :env_for)
          base.send(:alias_method, :env_for, :env_for_with_rollbar)
        end
      end
    end
  end
end
