require 'logger'
require 'rollbar'

module Rollbar
  # This class provides logger interface that can be used to replace
  # the application logger and send all the log messages to Rollbar
  #
  # Usage:
  # require 'rollbar/logger'
  # logger = Rollbar::Logger.new
  # logger.error('Error processing purchase')
  #
  # If using Rails, you can extend the Rails logger so messages are logged
  # normally and also to Rollbar:
  #
  # Rails.logger.extend(ActiveSupport::Logger.broadcast(Rollbar::Logger.new))
  class Logger < ::Logger
    class Error < RuntimeError; end
    class DatetimeFormatNotSupported < Error; end
    class FormatterNotSupported < Error; end

    def initialize
      @level = ERROR
    end

    def add(severity, message = nil, progname = nil)
      return true if severity < @level

      message ||= block_given? ? yield : progname

      return true if blank?(message)

      rollbar.log(rollbar_level(severity), message)
    end

    def <<(message)
      error(message)
    end

    def formatter=(_)
      raise(FormatterNotSupported)
    end

    def formatter
      raise(FormatterNotSupported)
    end

    def datetime_format=(_)
      raise(DatetimeFormatNotSupported)
    end

    def datetime_format
      raise(DatetimeFormatNotSupported)
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

    def blank?(message)
      return message.blank? if message.respond_to?(:blank?)

      message.respond_to?(:empty?) ? !!message.empty? : !message
    end

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
