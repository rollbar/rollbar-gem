require "logger"
require 'rollbar'

module Rollbar
  class Logger < Logger
    class Error < RuntimeError; end
    class DatetimeFormatNotSupported < Error; end
    class FormatterNotSupported < Error; end

    def initialize
      @level = ERROR
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if severity < @level

      message ||= block_given? ? yield : progname

      return true if message.blank?

      rollbar.log(rollbar_level(severity), message)
    end

    def <<(message)
      error(message)
    end

    def formatter=(_)
      fail(FormatterNotSupported)
    end

    def formatter
      fail(FormatterNotSupported)
    end

    def datetime_format=(_)
      fail(DatetimeFormatNotSupported)
    end

    def datetime_format
      fail(DatetimeFormatNotSupported)
    end

    # Returns a Rollbar::Notifier instance with the current global scope and
    # with a logger writing to /dev/null so we don't have a infinite loop
    # when Rollbar.configuration.logger is Rails.logger.
    def rollbar
      notifier = Rollbar.scope
      notifier.configuration.logger = ::Logger.new('/dev/null')

      notifier
    end

    private

    # Find correct Rollbar level to use using the indexes in Logger::Severity
    # DEBUG = 0
    # INFO = 1
    # WARN = 2
    # ERROR = 3
    # FATAL = 4
    # UNKNOWN = 5
    #
    # If not found we'll use 'error' as the used level
    def rollbar_level(severity)
      [:debug, :info, :warning, :error, :critical, :error][severity] || :error
    end
  end
end
