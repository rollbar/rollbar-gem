module Rollbar
  module ExceptionReporter
    include RequestDataExtractor

    def report_exception_to_rollbar(env, exception)
      Rollbar.log_info "Reporting exception: #{exception.message}"
      request_data = extract_request_data_from_rack(env)
      person_data = extract_person_data_from_controller(env)
      exception_data = Rollbar.report_exception(exception, request_data, person_data)

      if exception_data.is_a?(Hash)
        env['rollbar.exception_uuid'] = exception_data[:uuid]
        Rollbar.log_debug "[Rollbar] Exception uuid saved in env: #{exception_data[:uuid]}"
      elsif exception_data == 'disabled'
        Rollbar.log_debug "[Rollbar] Exception not reported because Rollbar is disabled"
      elsif exception_data == 'ignored'
        Rollbar.log_debug "[Rollbar] Exception not reported because it was ignored"
      end
    rescue => e
      Rollbar.log_debug "[Rollbar] Exception while reporting exception to Rollbar: #{e.message}"
    end
  end
end
