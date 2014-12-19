module Rollbar
  module Delay
    class Thread
      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        ::Thread.new { Rollbar.process_payload_safely(payload) }
      end
    end
  end
end
