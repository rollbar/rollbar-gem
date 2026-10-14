module Rollbar
  # Report any uncaught errors in a job to Rollbar and reraise
  module ActiveJob
    # Runs each job with an empty scope so it doesn't report data left over
    # from whatever ran before it on the same thread, e.g. the person and
    # request of a controller action when using the async or inline adapters.
    # The previous scope is restored afterwards. This wraps perform_now rather
    # than using around_perform because rescue_from handlers run outside the
    # perform callbacks.
    #
    # Jobs run by the Sidekiq integration, or by the delayed_job one with
    # dj_use_scoped_block, keep their scope, since those set it up for the job.
    module ResetScope
      def perform_now(*args, &block)
        return super if Rollbar::JobIntegration.within?

        Rollbar.scoped do
          Rollbar.reset_notifier!

          super
        end
      end
    end

    def self.included(base)
      if defined?(::ActiveJob::Base) && base <= ::ActiveJob::Base
        base.send :prepend, ResetScope
      end

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
