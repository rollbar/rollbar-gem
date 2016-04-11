module Rollbar
  class LoggerProxy
    attr_reader :object

    def initialize(object)
      @object = object
    end

    def debug(message)
      log('debug', message)
    end

    def info(message)
      log('info', message)
    end

    def warn(message)
      log('warn', message)
    end

    def error(message)
      log('error', message)
    end

    def log(level, message)
      return unless Rollbar.configuration.enabled

      @object.send(level, message)
    rescue
      puts "[Rollbar] Error logging #{level}:"
      puts "[Rollbar] #{message}"
    end
  end
end
