module Rollbar
  module Delay
    class DelayedJob
      class << self
        def call(payload)
          new.delay.call(payload)
        end
      end

      def call(payload)
        Rollbar.process_from_async_handler(payload)
      end
    end
  end
end
