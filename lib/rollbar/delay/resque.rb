require 'resque'

module Rollbar
  module Delay
    class Resque
      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        ::Resque.enqueue(Job, payload)
      end

      class Job
        def self.queue; 'default'; end

        def self.perform(payload)
          new.perform(payload)
        end

        def perform(payload)
          Rollbar.process_payload(payload)
        end
      end
    end
  end
end
