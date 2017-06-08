require 'shoryuken'

module Rollbar
  module Delay
    class Shoryuken
      include ::Shoryuken::Worker

      # not allowing bulk, to not double-report rollbars if one of them failed in bunch.
      shoryuken_options queue: -> { queue_name }, auto_delete: true, body_parser: :json, retry_intervals: [60, 180, 360, 1200, 3600, 18600]

      def self.queue_name
        "rollbar_#{Rollbar.configuration.environment.to_s}"
      end

      ## responsible for performing job. - payload is a json parsed body of the message.
      def perform(sqs_message, payload)
          Rollbar.process_from_async_handler(payload)
      end

      ## to push the job !
      def call(payload)
        self.class.perform_async(payload)
      end
    end
  end
end
