module Rollbar
  module ExceptionReporter
    def report_exception_to_rollbar(env, exception)
      Rollbar.log_debug "[Rollbar] Reporting exception: #{exception.try(:message)}"

      exception_data = Rollbar.log(Rollbar.configuration.uncaught_exception_level, exception)

      if exception_data.is_a?(Hash)
        env['rollbar.exception_uuid'] = exception_data[:uuid]
        Rollbar.log_debug "[Rollbar] Exception uuid saved in env: #{exception_data[:uuid]}"
      elsif exception_data == 'disabled'
        Rollbar.log_debug "[Rollbar] Exception not reported because Rollbar is disabled"
      elsif exception_data == 'ignored'
        Rollbar.log_debug "[Rollbar] Exception not reported because it was ignored"
      end
    rescue => e
      Rollbar.log_warning "[Rollbar] Exception while reporting exception to Rollbar: #{e.message}"
    end
  end
end
