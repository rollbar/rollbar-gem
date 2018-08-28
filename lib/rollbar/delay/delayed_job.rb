module Rollbar
  module Delay
    # This class provides the DelayedJob async handler. Users can
    # use DelayedJob in order to send the reports to the Rollbar API
    class DelayedJob
      class << self
        attr_accessor :queue

        def call(payload)
          if queue
            new.delay(:queue => queue).call(payload)
          else
            new.delay.call(payload)
          end
        end
      end

      def call(payload)
        Rollbar.process_from_async_handler(payload)
      end
    end
  end
end
