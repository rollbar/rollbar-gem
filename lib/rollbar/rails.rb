module Rollbar
  module Rails

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def on_exception_log_values(*vars)
        Rollbar.configuration.custom_values = [*vars].map(&:to_s)
      end
    end

  end
end
