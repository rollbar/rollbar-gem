require 'shoryuken'

module Rollbar
  module Delay
    # Following class allows to send rollbars using Sho-ryu-ken as a background jobs processor.
    # see the queue_name method which states that your queues needs to be names as "rollbar_ENVIRONMENT".
    # retry intervals will be used to retry sending the same message again if failed before.
    class Shoryuken
      include ::Shoryuken::Worker

      def self.queue_name
        "rollbar_#{Rollbar.configuration.environment}"
      end

      # not allowing bulk, to not double-report rollbars if one of them failed in bunch.
      shoryuken_options :queue => queue_name, :auto_delete => true, :body_parser => :json, :retry_intervals => [60, 180, 360, 120_0, 360_0, 186_00]

      ## responsible for performing job. - payload is a json parsed body of the message.
      def perform(_sqs_message, payload)
        Rollbar.process_from_async_handler(payload)
      end

      ## to push the job !
      def call(payload)
        self.class.perform_async(payload)
      end
    end
  end
end
