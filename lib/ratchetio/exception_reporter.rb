module Ratchetio
  module ExceptionReporter
    include RequestDataExtractor

    def report_exception_to_ratchetio(env, exception)
      ratchetio_debug "[Ratchet.io] Reporting exception: #{exception.try(:message)}", :error
      request_data = extract_request_data_from_rack(env)
      person_data = extract_person_data_from_controller(env)
      exception_data = Ratchetio.report_exception(exception, request_data, person_data)
      env['ratchetio.exception_uuid'] = exception_data[:uuid]
      ratchetio_debug "[Ratchet.io] Exception uuid saved in env: #{exception_data[:uuid]}"
    rescue => e
      ratchetio_debug "[Ratchet.io] Exception while reporting exception to Ratchet.io: #{e.try(:message)}"
    end

    def ratchetio_debug(message, level = :debug)
      if defined?(Rails)
        ::Rails.logger.send(level, message)
      else
        puts message
      end
    end
  end
end
