module Ratchetio
  module Rails
    module Middleware
      module ExceptionCatcher
        include RequestDataExtractor

        def self.included(base)
          base.send(:alias_method_chain, :render_exception, :ratchetio)
        end

        def render_exception_with_ratchetio(env, exception)
          exception_data = nil
          begin
            exception_data = report_exception_to_ratchetio(env, exception)
          rescue => e
            ::Rails.logger.warn "[Ratchet.io] Exception while reporting exception to Ratchet.io: #{e.try(:message)}"
          end

          # if an exception was reported, save uuid in the env
          # so it can be displayed to the user on the error page
          if exception_data
            begin
              env['ratchetio.exception_uuid'] = exception_data[:uuid]
              ::Rails.logger.debug "[Ratchet.io] Exception uuid saved in env: #{exception_data[:uuid]}"
            rescue => e
              ::Rails.logger.warn "[Ratchet.io] Exception saving uuid in env: #{e.try(:message)}"
            end
          end

          # now continue as normal
          render_exception_without_ratchetio(env, exception)
        end

        def report_exception_to_ratchetio(env, exception)
          ::Rails.logger.error "[Ratchet.io] Reporting exception: #{exception.try(:message)}"
          request_data = extract_request_data_from_rake(env)
          person_data = extract_person_data_from_controller(env)
          Ratchetio.report_exception(exception, request_data, person_data)
        end
      end
    end
  end
end
