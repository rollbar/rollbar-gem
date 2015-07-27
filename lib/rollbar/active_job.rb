module Rollbar
  # Report any uncaught errors in a job to Rollbar
  module ActiveJob
    def self.included(base)
      base.send :rescue_from, Exception do |exception|
        Rollbar.error(exception, :job => self.class.name, :job_id => job_id)
      end
    end
  end
end
