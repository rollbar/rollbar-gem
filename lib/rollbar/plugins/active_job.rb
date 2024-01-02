Rollbar.plugins.define('active_job') do
  dependency { !configuration.disable_monkey_patch }
  dependency { !configuration.disable_action_mailer_monkey_patch }

  execute do
    module Rollbar
      # Report any uncaught errors in a job to Rollbar and reraise
      module ActiveJob
        def self.included(base)
          base.send :rescue_from, Exception do |exception|
            args = if self.class.respond_to?(:log_arguments?) && !self.class.log_arguments?
                     arguments.map(&Rollbar::Scrubbers.method(:scrub_value))
                   else
                     arguments
                   end

            job_data = {
              :job => self.class.name,
              :use_exception_level_filters => true,
              :arguments => args
            }

            # job_id isn't present when this is a mailer class.
            job_data[:job_id] = job_id if defined?(job_id)

            Rollbar.error(exception, job_data)
            raise exception
          end
        end
      end
    end

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
