require 'shoryuken'

module Rollbar
  module Delay
    class Shoryuken
      include ::Shoryuken::Worker

      # not allowing bulk, to not double-report rollbars if one of them failed in bunch.
      shoryuken_options queue: ->{ "rollbar_#{Rollbar.configuration.environment.to_s}" }, auto_delete: true, body_parser: :json, retry_intervals: [60, 180, 360, 1200, 3600, 18600]

      ## responsible for performing job
      def perform(*args)
        begin
          Rollbar.process_from_async_handler(*args)
        rescue
          # Raise the exception so Shoryuken can track the errored job
          # and retry it
          raise
        end
      end

      ## to push the job !
      def call(payload)
        self.class.perform_async(payload)
      end
    end
  end
end
