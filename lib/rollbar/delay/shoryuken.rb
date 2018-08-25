require 'shoryuken'

module Rollbar
  module Delay
    # Following class allows to send rollbars using Sho-ryu-ken as a background jobs processor.
    # see the queue_name method which states that your queues needs to be names as "rollbar_ENVIRONMENT".
    # retry intervals will be used to retry sending the same message again if failed before.
    class Shoryuken
      include ::Shoryuken::Worker

      class << self
        attr_accessor :queue
      end

      self.queue = "rollbar_#{Rollbar.configuration.environment}"

      def self.call(payload)
        new.call(payload, :queue => queue)
      end

      def call(payload, options = {})
        self.class.perform_async(payload, options)
      end

      # not allowing bulk, to not double-report rollbars if one of them failed in bunch.
      shoryuken_options :auto_delete => true,
                        :body_parser => :json,
                        :retry_intervals => [60, 180, 360, 120_0, 360_0, 186_00]

      def perform(_sqs_message, payload)
        Rollbar.process_from_async_handler(payload)
      end
    end
  end
end
