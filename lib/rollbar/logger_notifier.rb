require "rollbar/notifier"
require "json"

# This overrides the Notifier in the original rollbar-gem.
#
# It overrides two methods:
#  1. #send_using_eventmachine(body)
#  2. #send_body(body)
# These two methods are the last methods called before messages are sent to the Rollbar server.
#
# The override allows for the injection of code that sends messages to the application log
#  before sending the messages to the Rollbar server.
#
module Rollbar
	class LoggerNotifier < Notifier
    # This is an override of a method in the original rollbar-gem.
    def send_using_eventmachine(body)
      format_and_log(body)
      super(body)
    end

    # This is an override of a method in the original rollbar-gem.
    def send_body(body)
      format_and_log(body)
      super(body)
    end

    # This method takes the messages meant to be sent to Rollbar's server and logs them to the application log,
    #  where the Datadog agent will pick up the messages and send them to Datadog.
    def format_and_log(body)
      body_hash = ::JSON.parse(body)

      # Skip logging to application logger for Datadog to pick up. Datadog is already configured to log uncaught errors directly.
      return if body_hash.dig("data", "body", "trace", "extra", "uncaught_error")
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