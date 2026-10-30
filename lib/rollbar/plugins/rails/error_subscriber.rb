module Rollbar
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source: nil)
      # The default `nil` for capture_uncaught means `true`. so check for false.
      return unless handled || Rollbar.configuration.capture_uncaught != false

      return if reported_by_active_job?(error)

      extra = context.is_a?(Hash) ? context.deep_dup : {}
      extra[:custom_data_method_context] = source

      # Rails auto injected context
      extra[:controller] = extra[:controller].class.name if extra[:controller]&.respond_to?(:class)
      extra[:job] = extra[:job].class.name if extra[:job]&.respond_to?(:class)
      extra[:is_uncaught] = !handled
      extra[:use_exception_level_filters] = !handled

      Rollbar.log(severity, error, extra)
    end

    private

    # Errors that escape a job reach here from the Rails executor after the
    # ActiveJob plugin has already reported them.
    def reported_by_active_job?(error)
      defined?(Rollbar::ActiveJob) && Rollbar::ActiveJob.reported?(error)
    end
  end
end
