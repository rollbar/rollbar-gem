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
          job_data[:arguments] = Rollbar::ActiveJob.job_arguments(self)
          job_data[:job_id] = job_id if defined?(job_id)

          Rollbar.error(exception, job_data)
        end

        raise exception
      end
    end

    def self.job_arguments(job)
      if job.class.respond_to?(:log_arguments?) && !job.class.log_arguments?
        job.arguments.map(&Rollbar::Scrubbers.method(:scrub_value))
      else
        job.arguments
      end
    end

    # Reports errors from ActionMailer delivery jobs.
    #
    # This wraps `perform_now` instead of registering a `rescue_from` handler,
    # so it only sees errors that weren't handled by the delivery job
    # (`discard_on`, `retry_on`, `rescue_from`) or by the mailer's own
    # `rescue_from` handlers, which the delivery job delegates to.
    module MailerDeliveryJob
      def perform_now
        super
      rescue Exception => e # rubocop:disable Lint/RescueException
        Rollbar.error(e,
                      :job => self.class.name,
                      :job_id => job_id,
                      :use_exception_level_filters => true,
                      :arguments => Rollbar::ActiveJob.job_arguments(self))
        raise
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
          ActionMailer::MailDeliveryJob.send(:prepend,
                                             Rollbar::ActiveJob::MailerDeliveryJob)
        end

        # Rails < 7.0. Also still used on Rails 6.x by apps that haven't
        # switched `delivery_job` to MailDeliveryJob.
        if defined?(ActionMailer::DeliveryJob)
          ActionMailer::DeliveryJob.send(:prepend,
                                         Rollbar::ActiveJob::MailerDeliveryJob)
        end
      end
    end
  end
end
