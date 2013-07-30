require 'sidekiq'

module Rollbar
  module Delay
    class Sidekiq
      OPTIONS = { 'queue' => 'rollbar', 'class' => self.name }.freeze

      def self.handle(payload)
        item = @use_sidekiq.is_a?(Hash) ? OPTIONS.merge(@use_sidekiq) : OPTIONS

        ::Sidekiq::Client.push item.merge('args' => [payload])
      end

      include ::Sidekiq::Worker

      def perform(*args)
        Rollbar.process_payload(*args)
      end
    end
  end
end
