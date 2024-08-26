module Rollbar
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source: nil)
      extra = context.is_a?(Hash) ? context.deep_dup : {}
      extra[:custom_data_method_context] = source
      Rollbar.log(severity, error, extra)
    end
  end
end
