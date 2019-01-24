module Rollbar
  module Delay
    # This class provides the ActiveJob async handler. Users can
    # use ActiveJob in order to send the reports to the Rollbar API
    class ActiveJob < ::ActiveJob::Base
      
      def self.default_queue_name
        :default
      end
      
      queue_as default_queue_name
      
      def perform(payload)
        Rollbar.process_from_async_handler(payload)
      end
      
      def self.call(payload)
        perform_later payload
      end
      
    end
  end
end
