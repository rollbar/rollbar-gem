module Rollbar
  module ExceptionReporter # :nodoc:
    def report_exception_to_rollbar(env, exception)
      return unless capture_uncaught?

      log_exception_message(exception)

      exception_data = exception_data(exception)

      case exception_data
      when Hash
        env['rollbar.exception_uuid'] = exception_data[:uuid]
        Rollbar.log_debug(
          "[Rollbar] Exception uuid saved in env: #{exception_data[:uuid]}"
        )
      when 'disabled'
        Rollbar.log_debug(
          '[Rollbar] Exception not reported because Rollbar is disabled'
        )
      when 'ignored'
        Rollbar.log_debug '[Rollbar] Exception not reported because it was ignored'
      end
    rescue StandardError => e
      Rollbar.log_warning(
        "[Rollbar] Exception while reporting exception to Rollbar: #{e.message}"
      )
    end

    def capture_uncaught?
      Rollbar.configuration.capture_uncaught != false &&
        !Rollbar.configuration.enable_rails_error_subscriber
    end

    def log_exception_message(exception)
      exception_message = exception.message if exception.respond_to?(:message)
      exception_message ||= 'No Exception Message'
      Rollbar.log_debug "[Rollbar] Reporting exception: #{exception_message}"
    end

    def exception_data(exception)
      Rollbar.log(Rollbar.configuration.uncaught_exception_level, exception,
                  :use_exception_level_filters => true)
    end
  end
end
