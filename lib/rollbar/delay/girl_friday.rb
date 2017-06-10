module Rollbar
  module Delay
    class GirlFriday
      class << self
        def queue_class
          ::GirlFriday::WorkQueue
        end

        def call(payload)
          new.call(payload)
        end

        def queue
          @queue ||= self.queue_class.new(nil, :size => 5) do |payload|
            begin
              Rollbar.process_from_async_handler(payload)
            rescue
              # According to https://github.com/mperham/girl_friday/wiki#error-handling
              # we reraise the exception so it can be handled some way
              raise
            end
          end
        end
      end

      def call(payload)
        self.class.queue.push(payload)
      end
    end
  end
end
