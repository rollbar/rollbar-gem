module Rollbar
  class Backtrace
    attr_reader :exception
    attr_reader :message
    attr_reader :extra
    attr_reader :configuration

    def initialize(exception, options = {})
      @exception = exception
      @message = options[:message]
      @extra = options[:extra]
      @configuration = options[:configuration]
    end

    def build
      traces = trace_chain

      traces[0][:exception][:description] = message if message
      traces[0][:extra] = extra if extra

      if traces.size > 1
        { :trace_chain => traces }
      elsif traces.size == 1
        { :trace => traces[0] }
      end
    end

    private

    def trace_chain
      exception
      traces = [trace_data(exception)]
      visited = [exception]

      current_exception = exception

      while current_exception.respond_to?(:cause) && (cause = current_exception.cause) && cause.is_a?(Exception) && !visited.include?(cause)
        traces << trace_data(cause)
        visited << cause
        current_exception = cause
      end

      traces
    end

    def trace_data(current_exception)
      frames = exception_backtrace(current_exception).map do |frame|
        # parse the line
        match = frame.match(/(.*):(\d+)(?::in `([^']+)')?/)

        if match
          { :filename => match[1], :lineno => match[2].to_i, :method => match[3] }
        else
          { :filename => "<unknown>", :lineno => 0, :method => frame }
        end
      end

      # reverse so that the order is as rollbar expects
      frames.reverse!

      {
        :frames => frames,
        :exception => {
          :class => current_exception.class.name,
          :message => current_exception.message
        }
      }
    end

    # Returns the backtrace to be sent to our API. There are 3 options:
    #
    # 1. The exception received has a backtrace, then that backtrace is returned.
    # 2. configuration.populate_empty_backtraces is disabled, we return [] here
    # 3. The user has configuration.populate_empty_backtraces is enabled, then:
    #
    # We want to send the caller as backtrace, but the first lines of that array
    # are those from the user's Rollbar.error line until this method. We want
    # to remove those lines.
    def exception_backtrace(current_exception)
      return current_exception.backtrace if current_exception.backtrace.respond_to?( :map )
      return [] unless configuration.populate_empty_backtraces

      caller_backtrace = caller
      caller_backtrace.shift while caller_backtrace[0].include?(rollbar_lib_gem_dir)
      caller_backtrace
    end

    def rollbar_lib_gem_dir
      Gem::Specification.find_by_name('rollbar').gem_dir + '/lib'
    end
  end
end
