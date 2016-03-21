require 'thread'
require 'timeout'

module Rollbar
  module Delay
    class Thread
      EXIT_SIGNAL  = :exit
      EXIT_TIMEOUT = 3

      Error        = Class.new(StandardError)
      TimeoutError = Class.new(Error)

      class << self
        attr_reader :reaper

        def call(payload)
          spawn_threads_reaper
          threads << new.call(payload)
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

              if thread == EXIT_SIGNAL
                break
              else
                thread.join
              end
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

      def call(payload)
        ::Thread.new do
          begin
            Rollbar.process_from_async_handler(payload)
          rescue
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
