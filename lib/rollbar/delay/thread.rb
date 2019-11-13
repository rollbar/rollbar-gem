require 'timeout'

module Rollbar
  module Delay
    class Thread
      EXIT_SIGNAL  = :exit
      EXIT_TIMEOUT = 6

      Error        = Class.new(StandardError)
      TimeoutError = Class.new(Error)

      DEFAULT_PRIORITY = 1

      class << self
        attr_writer :options
        attr_reader :reaper

        def call(payload)
          spawn_threads_reaper

          thread = new.call(payload)
          threads << thread
          thread
        end

        def options
          @options || {}
        end

        private

        def threads
          @threads ||= Queue.new
        end

        def spawn_threads_reaper
          return if @spawned

          @spawned = true

          @reaper ||= build_reaper_thread
          configure_exit_handler
        end

        def build_reaper_thread
          ::Thread.start do
            loop do
              thread = threads.pop

              break if thread == EXIT_SIGNAL

              thread.join
            end
          end
        end

        def configure_exit_handler
          at_exit do
            begin
              Timeout.timeout(EXIT_TIMEOUT) do
                threads << EXIT_SIGNAL
                reaper.join
              end
            rescue Timeout::Error
              raise TimeoutError, "unable to reap all threads within #{EXIT_TIMEOUT} seconds"
            end
          end
        end
      end # class << self

      def priority
        self.class.options[:priority] || DEFAULT_PRIORITY
      end

      def call(payload)
        priority = self.priority

        ::Thread.new do
          begin
            ::Thread.current.priority = priority
            Rollbar.process_from_async_handler(payload)
          rescue StandardError
            # Here we swallow the exception:
            # 1. The original report wasn't sent.
            # 2. An internal error was sent and logged
            #
            # If users want to handle this in some way they
            # can provide a more custom Thread based implementation
          end
        end
      end
    end
  end
end
