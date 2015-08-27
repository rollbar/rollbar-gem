require 'sucker_punch'

module Rollbar
  module Delay
    class SuckerPunch

      include ::SuckerPunch::Job

      def self.call(payload)
        new.async.perform payload
      end

      def perform(*args)
        begin
          Rollbar.process_payload_safely(*args)
        rescue
          # SuckerPunch can configure an exception handler with:
          #
          # SuckerPunch.exception_handler { # do something here }
          #
          # This is just passed to Celluloid.exception_handler which will
          # push the reiceved block to an array of handlers, by default empty, [].
          #
          # We reraise the exception here casue it's safe and users could have defined
          # their own exception handler for SuckerPunch
          raise
        end
      end
    end
  end
end
