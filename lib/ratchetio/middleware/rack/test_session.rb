module Ratchetio
  module Middleware
    module Rack
      module TestSession
        include ExceptionReporter

        def process_request_with_ratchetio(uri, env, &block)
          process_request_without_ratchetio(uri, env, &block)
        rescue => exception
          report_exception_to_ratchetio(env, exception)
          raise exception
        end

        def env_for_with_ratchetio(path, env)
          env_for_without_ratchetio(path, env)
        rescue => exception
          report_exception_to_ratchetio(env, exception)
          raise exception
        end

        def self.included(base)
          base.send(:alias_method, :process_request_without_ratchetio, :process_request)
          base.send(:alias_method, :process_request, :process_request_with_ratchetio)

          base.send(:alias_method, :env_for_without_ratchetio, :env_for)
          base.send(:alias_method, :env_for, :env_for_with_ratchetio)
        end
      end
    end
  end
end
