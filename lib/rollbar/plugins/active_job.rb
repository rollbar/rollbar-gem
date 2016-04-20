module Rollbar
  # Report any uncaught errors in a job to Rollbar and reraise
  module ActiveJob
    def self.included(base)
      base.send :rescue_from, Exception do |exception|
        Rollbar.error(exception, :job => self.class.name, :job_id => job_id)
        raise exception
      end
    end
  end
end
