require 'rollbar/delay/rollbar_report_job'

module Rollbar
  module Delay
    # This class provides the ActiveJob async handler. Users can
    # use ActiveJob in order to send the reports to the Rollbar API
    class ActiveJob
      @@queue = :rollbar
      
      class << self
        def queue
          @@queue
        end
        
        def queue=(val)
          @@queue = val
        end
        
        def call(payload)
          RollbarReportJob.perform_later payload
        end
      end
    end
  end
end
