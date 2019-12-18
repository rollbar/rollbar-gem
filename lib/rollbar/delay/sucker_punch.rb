require 'sucker_punch'
require 'sucker_punch/version'

module Rollbar
  module Delay
    class SuckerPunch
      include ::SuckerPunch::Job

      class << self
        attr_accessor :perform_proc
        attr_accessor :ready
      end

      self.ready = false

      def self.setup
        major_version = ::SuckerPunch::VERSION.split.first.to_i

        self.perform_proc = if major_version > 1
                              proc { |payload| perform_async(payload) }
                            else
                              proc { |payload| new.async.perform(payload) }
                            end

        self.ready = true
      end

      def self.call(payload)
        setup unless ready

        perform_proc.call(payload)
      end

      def perform(*args)
        Rollbar.process_from_async_handler(*args)

        # SuckerPunch can configure an exception handler with:
        #
        # SuckerPunch.exception_handler { # do something here }
        #
        # This is just passed to Celluloid.exception_handler which will
        # push the reiceved block to an array of handlers, by default empty, [].
        #

        # Do not rescue. SuckerPunch will call the error handler.
      end
    end
  end
end
