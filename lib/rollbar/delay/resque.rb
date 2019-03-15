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
        class << self
          attr_accessor :queue
        end

        self.queue = :default

        def self.perform(payload)
          new.perform(payload)
        end

        def perform(payload)
          Rollbar.process_from_async_handler(payload)
        rescue StandardError
          # Raise the exception so Resque can track the errored job
          raise
        end
      end
    end
  end
end
