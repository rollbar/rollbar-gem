module Ratchetio
  module Middleware
    module Rails
      module ShowExceptions
        include ExceptionReporter

        def render_exception_with_ratchetio(env, exception)
          report_exception_to_ratchetio(env, exception)
          render_exception_without_ratchetio(env, exception)
        end

        def call_with_ratchetio(env)
          call_without_ratchetio(env)
        rescue => exception
          report_exception_to_ratchetio(env, exception)
          raise exception
        end

        def self.included(base)
          base.send(:alias_method_chain, :render_exception, :ratchetio)
          base.send(:alias_method_chain, :call, :ratchetio)
        end
      end
    end
  end
end
