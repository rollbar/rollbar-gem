require 'rollbar'

module Resque
  module Failure
    # Falure class to use in Resque in order to send
    # Resque errors to the Rollbar API
    class Rollbar < Base
      def save
        payload_with_options =
          if use_exception_level_filters?
            payload.merge(:use_exception_level_filters => true)
          else
            payload
          end

        rollbar.error(exception, payload_with_options)
      end

      private

      # We want to disable async reporting since original
      # resque-rollbar implementation disabled it.
      def rollbar
        notifier = ::Rollbar.notifier.scope
        notifier.configuration.use_async = false

        notifier
      end

      def use_exception_level_filters?
        Gem::Version.new(rollbar_version) > Gem::Version.new('1.3.0')
      end

      def rollbar_version
        ::Rollbar::VERSION
      end
    end
  end
end
