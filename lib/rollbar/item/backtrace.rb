require 'rollbar/item/frame'

module Rollbar
  class Item
    class Backtrace
      attr_reader :exception
      attr_reader :message
      attr_reader :extra
      attr_reader :configuration
      attr_reader :files

      private :files

      def initialize(exception, options = {})
        @exception = exception
        @message = options[:message]
        @extra = options[:extra]
        @configuration = options[:configuration]
        @files = {}
      end

      def to_h
        traces = trace_chain

        traces[0][:exception][:description] = message if message
        traces[0][:extra] = extra if extra

        if traces.size > 1
          { :trace_chain => traces }
        elsif traces.size == 1
          { :trace => traces[0] }
        end
      end

      alias build to_h

      def get_file_lines(filename)
        files[filename] ||= read_file(filename)
      end

      private

      def read_file(filename)
        return unless File.exist?(filename)

        File.read(filename).split("\n")
      rescue StandardError
        nil
      end

      def trace_chain
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
        {
          :frames => map_frames(current_exception),
          :exception => {
            :class => current_exception.class.name,
            :message => current_exception.message
          }
        }
      end

      def map_frames(current_exception)
        frames = cleaned_backtrace(current_exception).map do |frame|
          Rollbar::Item::Frame.new(self, frame,
                                   :configuration => configuration).to_h
        end
        frames.reverse!
      end

      def cleaned_backtrace(current_exception)
        normalized_backtrace = exception_backtrace(current_exception)
        if configuration.backtrace_cleaner
          configuration.backtrace_cleaner.clean(normalized_backtrace)
        else
          normalized_backtrace
        end
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
        return current_exception.backtrace if current_exception.backtrace.respond_to?(:map)
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
end
