module Ratchetio
  module Rails
    module Middleware
      module ExceptionCatcher
        def self.included(base)
          base.send(:alias_method_chain, :render_exception, :ratchetio)
        end

        def render_exception_with_ratchetio(env, exception)
          Ratchetio.report_exception(env, exception)
          render_exception_without_ratchetio(env, exception)
        end
      end
    end
  end
end
