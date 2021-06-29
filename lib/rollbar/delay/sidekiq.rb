require 'sidekiq'

module Rollbar
  module Delay
    class Sidekiq
      OPTIONS = { 'queue' => 'rollbar', 'class' => Rollbar::Delay::Sidekiq }.freeze

      def initialize(*args)
        @options = (opts = args.shift) ? OPTIONS.merge(opts) : OPTIONS
      end

      def call(payload)
        return unless ::Sidekiq::Client.push(@options.merge('args' => [payload])).nil?

        raise(StandardError, 'Unable to push the job to Sidekiq')
      end

      include ::Sidekiq::Worker

      def perform(*args)
        Rollbar.process_from_async_handler(*args)

        # Do not rescue. Sidekiq will call the error handler.
      end
    end
  end
end
