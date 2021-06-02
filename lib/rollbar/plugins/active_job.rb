module Rollbar
  # Report any uncaught errors in a job to Rollbar and reraise
  module ActiveJob
    def self.included(base)
      base.send :rescue_from, Exception do |exception|
        Rollbar.error(exception,
                      :job => self.class.name,
                      :job_id => job_id,
                      :use_exception_level_filters => true,
                      :arguments => arguments)
        raise exception
      end
    end
  end
end

if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
  ActiveSupport.on_load(:action_mailer) do
    # Automatically add to ActionMailer::DeliveryJob
    if defined?(ActionMailer::DeliveryJob)
      ActionMailer::DeliveryJob.send(:include,
                                     Rollbar::ActiveJob)
    end
  end
end
