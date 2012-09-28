module Ratchetio
  module Rails
    module Middleware
      module ExceptionCatcher
        def self.included(base)
          base.send(:alias_method_chain, :render_exception, :ratchetio)
        end

        def render_exception_with_ratchetio(env, exception)
          # wrap everything in a begin-rescue block
          begin
            controller = env['action_controller.instance']
            request_data = controller.try(:ratchetio_request_data)
            person_data = controller.try(:ratchetio_person_data)
            Ratchetio.report_request_exception(env, exception, request_data, person_data)
          rescue Exception => exc
            # TODO use logger here?
            puts "[Ratchet.io] Exception while reporting exception to Ratchet.io: " 
            puts exc
          end

          # now continue as normal
          render_exception_without_ratchetio(env, exception)
        end
      end
    end
  end
end
