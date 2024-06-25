module Rollbar
  # Report any uncaught errors in a job to Rollbar and reraise
  module ActiveJob
    def self.included(base)
      base.send :rescue_from, Exception do |exception|
        job_data = {
          :job => self.class.name,
          :use_exception_level_filters => true
        }

        # When included in ActionMailer, the handler is called twice.
        # This detects the execution that has the expected state.
        if defined?(ActionMailer::Base) && self.class.ancestors.include?(ActionMailer::Base)
          job_data[:action] = action_name
          job_data[:params] = @params

          Rollbar.error(exception, job_data)

        # This detects other supported integrations.
        elsif defined?(arguments)
          job_data[:arguments] = \
            if self.class.respond_to?(:log_arguments?) && !self.class.log_arguments?
              arguments.map(&Rollbar::Scrubbers.method(:scrub_value))
            else
              arguments
            end
          job_data[:job_id] = job_id if defined?(job_id)

          Rollbar.error(exception, job_data)
        end

        raise exception
      end
    end
  end
end

Rollbar.plugins.define('active_job') do
  dependency { !configuration.disable_monkey_patch }
  dependency { !configuration.disable_action_mailer_monkey_patch }

  execute do
    if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
      ActiveSupport.on_load(:action_mailer) do
        if defined?(ActionMailer::MailDeliveryJob) # Rails >= 6.0
          ActionMailer::Base.send(:include, Rollbar::ActiveJob)
        elsif defined?(ActionMailer::DeliveryJob) # Rails < 6.0
          ActionMailer::DeliveryJob.send(:include,
                                         Rollbar::ActiveJob)
        end
      end
    end
  end
end
