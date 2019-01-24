require 'rollbar/delay/active_job'

module Rollbar
  module Delay
    # RollbarReportJob is used as the default class for Rollbar reporting jobs using the ActiveJob framework
    # TO DO: Consider merging this class with rollbar/delay/active_job into one
    class RollbarReportJob < ::ActiveJob::Base
      queue_as Rollbar::Delay::ActiveJob.queue
      
      def perform(payload)
        Rollbar.process_from_async_handler(payload)
      end
    end
  end
end