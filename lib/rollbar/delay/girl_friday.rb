module Rollbar
  module Delay
    class GirlFriday

      class << self
        attr_accessor :queue

        def call(payload)
          new.call(payload)
        end
      end

      def queue_class
        ::GirlFriday::WorkQueue
      end

      def call(payload)
        self.class.queue = queue_class.new(nil, :size => 5) do |payload|
          Rollbar.process_payload_safely(payload)
        end

        self.class.queue.push(payload)
      end
    end
  end
end
