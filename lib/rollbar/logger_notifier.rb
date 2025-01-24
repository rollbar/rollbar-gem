require "rollbar/notifier"
require "json"

module Rollbar
	class LoggerNotifier < Notifier
    def send_using_eventmachine(body)
      format_and_log(body)
      super(body)
    end

    def send_body(body)
      format_and_log(body)
      super(body)
    end

    def format_and_log(body)
      body_hash = ::JSON.parse(body)

      # Skip logging to application logger for Datadog to pick up. Datadog is already configured to log uncaught errors directly.
      return if body_hash.dig("data", "body", "message", "extra", "uncaught_error")

      level = body_hash.dig("data", "level")
      method_name = :error

      # Rollbar levels: https://github.com/rollbar/rollbar-gem/blob/f9d0be72a8048a5e8ae54200c84a5dff2fe513fb/lib/rollbar/logger.rb#L67-L69
      case level
      when "debug"
        method_name = :debug
      when "info"
        method_name = :info
      when "warning"
        method_name = :warn
      when "error"
        method_name = :error
      when "critical"
        method_name = :fatal
      end

      ::Rails.logger.send(method_name, body)
    end
	end
end