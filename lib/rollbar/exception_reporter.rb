module Rollbar
  module ExceptionReporter
    include RequestDataExtractor

    def report_exception_to_rollbar(env, exception)
      rollbar_debug "[Rollbar] Reporting exception: #{exception.try(:message)}", :error
      request_data = extract_request_data_from_rack(env)
      person_data = extract_person_data_from_controller(env)
      exception_data = Rollbar.report_exception(exception, request_data, person_data)
      
      if exception_data.is_a?(Hash)
        env['rollbar.exception_uuid'] = exception_data[:uuid]
        rollbar_debug "[Rollbar] Exception uuid saved in env: #{exception_data[:uuid]}"
      elsif exception_data == 'disabled'
        rollbar_debug "[Rollbar] Exception not reported because Rollbar is disabled"
      elsif exception_data == 'ignored'
        rollbar_debug "[Rollbar] Exception not reported because it was ignored"
      end
    rescue => e
      rollbar_debug "[Rollbar] Exception while reporting exception to Rollbar: #{e.try(:message)}"
    end

    def rollbar_debug(message, level = :debug)
      if defined?(Rails)
        ::Rails.logger.send(level, message)
      else
        puts message
      end
    end
  end
end
