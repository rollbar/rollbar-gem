require 'forwardable'

module Rollbar
  class Item
    # Builds a backtrace from the current call stack for reports that have none:
    # exceptions that were never raised, and messages when
    # `populate_message_backtraces` is enabled.
    module CallerBacktrace
      class << self
        # Returns the caller's backtrace without the frames at the top that are
        # inside this gem, so it starts at the user's Rollbar.error line.
        #
        # Rollbar.error and the other module methods are Forwardable delegators,
        # so their frames sit between the user's line and the gem's own frames.
        # Messages logged through Rollbar::Logger also pass through Ruby's
        # Logger#error and friends, and through ActiveSupport's broadcast
        # loggers when it is attached to the Rails logger.
        def backtrace
          skipped_files = [rollbar_lib_gem_dir, forwardable_file] + logger_files
          caller_backtrace = caller
          while caller_backtrace[0] &&
                skipped_files.any? { |file| caller_backtrace[0].include?(file) }
            caller_backtrace.shift
          end
          caller_backtrace
        end

        private

        def forwardable_file
          source_file(Forwardable, :def_instance_delegator)
        end

        def logger_files
          files = []
          files << source_file(::Logger, :error) if defined?(::Logger)
          if defined?(::ActiveSupport::Logger)
            files << source_file(::ActiveSupport::Logger, :initialize)
          end
          if defined?(::ActiveSupport::BroadcastLogger)
            files << source_file(::ActiveSupport::BroadcastLogger, :broadcast_to)
          end
          files.compact
        end

        def source_file(mod, method_name)
          location = mod.instance_method(method_name).source_location
          location && location[0]
        end

        def rollbar_lib_gem_dir
          gem_dir = Gem::Specification.find_by_name('rollbar').gem_dir
          "#{gem_dir}/lib"
        end
      end
    end
  end
end
