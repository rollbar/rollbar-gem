module Rollbar
  # Report any uncaught errors in a job to Rollbar and reraise
  module ActiveJob
    def self.included(base)
      # retry_on and discard_on are built on rescue_from, and Rails runs only the
      # most recently declared handler that matches. A rescue_from Exception
      # handler here would either hide those handlers or be hidden by them, so
      # for jobs we wrap perform_now instead. That reports only the errors that
      # escape the job: not a failed attempt that retry_on has rescheduled, but
      # the error re-raised once its attempts are exhausted.
      if defined?(::ActiveJob::Base) && base <= ::ActiveJob::Base
        base.send(:prepend, PerformNow) unless base < PerformNow
        return
      end

      base.send :rescue_from, Exception do |exception|
        job_data = {
          :job => self.class.name,
          :use_exception_level_filters => true
        }

        # When included in ActionMailer, errors raised by the mailer instance
        # hit this handler twice: once on the instance, and again on the mailer
        # class when MailDeliveryJob re-handles the re-raised error.
        if defined?(ActionMailer::Base) && self.class.ancestors.include?(ActionMailer::Base)
          job_data[:action] = action_name
          job_data[:params] = @params

          Rollbar.error(exception, job_data)
          Rollbar::ActiveJob.mark_reported(exception)

        # Errors raised before a mailer instance exists, such as
        # ActiveJob::DeserializationError, only reach the mailer class.
        elsif defined?(ActionMailer::Base) && is_a?(Class) && self <= ActionMailer::Base
          unless Rollbar::ActiveJob.reported?(exception)
            Rollbar.error(exception, job_data.merge(:job => name))
          end

        # This detects other supported integrations.
        elsif defined?(arguments)
          Rollbar.error(exception, Rollbar::ActiveJob.job_data(self))
        end

        raise exception
      end
    end

    # Prepended to ActiveJob classes. See ActiveJob.included.
    module PerformNow
      def perform_now
        super
      rescue Exception => e # rubocop:disable Lint/RescueException
        # The same error can escape more than one perform_now: MailDeliveryJob
        # re-raises errors the mailer already reported, and adapters that run
        # retries inline re-raise the last attempt's error through each
        # earlier attempt.
        unless Rollbar::ActiveJob.reported?(e)
          Rollbar.error(e, Rollbar::ActiveJob.job_data(self))
          Rollbar::ActiveJob.mark_reported(e)
        end

        raise
      end
    end

    def self.job_data(job)
      job_data = {
        :job => job.class.name,
        :use_exception_level_filters => true
      }
      job_data[:arguments] = \
        if job.class.respond_to?(:log_arguments?) && !job.class.log_arguments?
          job.arguments.map(&Rollbar::Scrubbers.method(:scrub_value))
        else
          job.arguments
        end
      job_data[:job_id] = job.job_id if job.respond_to?(:job_id)
      job_data
    end

    def self.mark_reported(exception)
      return if exception.frozen?

      exception.instance_variable_set(:@_rollbar_reported_by_active_job, true)
    end

    def self.reported?(exception)
      exception.instance_variable_get(:@_rollbar_reported_by_active_job)
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
