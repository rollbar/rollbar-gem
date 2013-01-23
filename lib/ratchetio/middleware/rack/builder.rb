module Ratchetio
  module Middleware
    module Rack
      module Builder
        include ExceptionReporter

        def call_with_ratchetio(env)
          call_without_ratchetio(env)
        rescue => exception
          report_exception_to_ratchetio(env, exception)
          raise exception
        end

        def self.included(base)
          base.send(:alias_method, :call_without_ratchetio, :call)
          base.send(:alias_method, :call, :call_with_ratchetio)
        end
      end
    end
  end
end
