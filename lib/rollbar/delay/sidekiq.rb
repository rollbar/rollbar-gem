require 'sidekiq'

module Rollbar
  module Delay
    class Sidekiq
      OPTIONS = { 'queue' => 'rollbar', 'class' => self.name }.freeze

      def initialize(*args)
        @options = (opts = args.shift) ? OPTIONS.merge(opts) : OPTIONS
      end

      def call(payload)
        ::Sidekiq::Client.push @options.merge('args' => [payload])
      end

      include ::Sidekiq::Worker

      def perform(*args)
        Rollbar.process_payload(*args)
      end
    end
  end
end
