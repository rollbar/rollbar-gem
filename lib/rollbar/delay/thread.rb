require 'timeout'

module Rollbar
  module Delay
    class Thread
      EXIT_SIGNAL  = :exit
      EXIT_TIMEOUT = 6

      Error        = Class.new(StandardError)
      TimeoutError = Class.new(Error)

      DEFAULT_PRIORITY = 1

      SLOTS_MUTEX = Mutex.new

      # Counts the reports a handler class has in flight, so .call can bound
      # them with the max_queue option.
      class Slots
        def initialize
          @mutex = Mutex.new
        end

        # Returns :acquired, or :queue_full for the first item dropped since
        # the queue filled up and :dropping for the ones after it, so a tight
        # error loop logs one warning instead of one per dropped item.
        def acquire(max)
          @mutex.synchronize do
            reset_after_fork

            if max && @pending >= max
              return :dropping if @dropping

              @dropping = true
              return :queue_full
            end

            @pending += 1
            :acquired
          end
        end

        def release
          # Clamped at zero, so an instance called directly (which never
          # acquired a slot) can't push the count negative. Direct calls still
          # aren't bounded by max_queue: only .call acquires slots.
          @mutex.synchronize do
            reset_after_fork
            @pending = [@pending - 1, 0].max
            @dropping = false
          end
        end

        def pending
          @mutex.synchronize do
            reset_after_fork
            @pending
          end
        end

        private

        # A forked child inherits the parent's count, but not the threads
        # holding those slots, so their `ensure` never runs in the child to
        # give the slots back. Start the count over in each new process.
        def reset_after_fork
          return if @pid == Process.pid

          @pid = Process.pid
          @pending = 0
          @dropping = false
        end
      end

      class << self
        attr_writer :options
        attr_reader :reaper

        def call(payload)
          case slots.acquire(max_queue)
          when :queue_full then return log_queue_full
          when :dropping then return
          end

          begin
            spawn_threads_reaper
            thread = new.call(payload)
          rescue StandardError
            release_slot
            raise
          end

          threads << thread
          thread
        end

        def options
          @options || {}
        end

        def pending_count
          slots.pending
        end

        def release_slot
          slots.release
        end

        private

        def max_queue
          options[:max_queue]
        end

        # Lazily set per class, so subclasses get their own count.
        def slots
          SLOTS_MUTEX.synchronize { @slots ||= Slots.new }
        end

        def log_queue_full
          Rollbar.log_warning(
            "[Rollbar] Thread queue is full (max_queue: #{max_queue}). " \
              'Dropping items until a pending report finishes.'
          )
          nil
        end

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
              raise TimeoutError,
                    "unable to reap all threads within #{EXIT_TIMEOUT} seconds"
            end
          end
        end
      end

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
          ensure
            self.class.release_slot
          end
        end
      end
    end
  end
end
