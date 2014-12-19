require 'sucker_punch'

module Rollbar
  module Delay
    class SuckerPunch

      include ::SuckerPunch::Job

      def self.call(payload)
        new.async.perform payload
      end

      def perform(*args)
        Rollbar.process_payload_safely(*args)
      end
    end
  end
end
