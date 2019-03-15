require 'sidekiq'

module Rollbar
  module Delay
    class Sidekiq
      OPTIONS = { 'queue' => 'rollbar', 'class' => Rollbar::Delay::Sidekiq }.freeze

      def initialize(*args)
        @options = (opts = args.shift) ? OPTIONS.merge(opts) : OPTIONS
      end

      def call(payload)
        raise StandardError, 'Unable to push the job to Sidekiq' if ::Sidekiq::Client.push(@options.merge('args' => [payload])).nil?
      end

      include ::Sidekiq::Worker

      def perform(*args)
        Rollbar.process_from_async_handler(*args)
      rescue StandardError
        # Raise the exception so Sidekiq can track the errored job
        # and retry it
        raise
      end
    end
  end
end
