require "logger"

module Rollbar
  class Logger < Logger
    def initialize
      @level = ERROR
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if severity < @level
      message ||= block_given? ? yield : progname
      return true if message.blank?
      rollbar_level = [:debug, :info, :warning, :error, :critical, :error][severity] || :error
      Rollbar.log(rollbar_level, message)
    end
  end
end
