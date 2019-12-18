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
          @queue ||= queue_class.new(nil, :size => 5) do |payload|
            Rollbar.process_from_async_handler(payload)

            # Do not rescue. GirlFriday will call the error handler.
          end
        end
      end

      def call(payload)
        self.class.queue.push(payload)
      end
    end
  end
end
