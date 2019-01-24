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
      end
    end
  end
end
