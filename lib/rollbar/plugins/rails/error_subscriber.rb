module Rollbar
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source: nil)
      # The default `nil` for capture_uncaught means `true`. so check for false.
      return unless handled || Rollbar.configuration.capture_uncaught != false

      extra = context.is_a?(Hash) ? context.deep_dup : {}
      extra[:custom_data_method_context] = source

      # Rails auto injected context
      extra[:controller] = extra[:controller].class.name if extra[:controller]&.respond_to?(:class)
      extra[:job] = extra[:job].class.name if extra[:job]&.respond_to?(:class)

      Rollbar.log(severity, error, extra)
    end
  end
end
