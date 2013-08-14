require 'sucker_punch'

module Rollbar
  module Delay
    class SuckerPunch
      def self.handle(payload)
        @@sucker_punch_worker ||= self.new
        @@sucker_punch_worker.async.perform payload
      end

      include ::SuckerPunch::Job

      def perform(*args)
        Rollbar.process_payload(*args)
      end
    end
  end
end
