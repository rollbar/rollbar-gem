Rollbar.plugins.define('active_model') do
  dependency { !configuration.disable_monkey_patch }
  dependency { defined?(ActiveModel::Validations) }
  dependency do
    require 'active_model/version'

    ActiveModel::VERSION::MAJOR >= 3
  end

  execute! do
    module Rollbar
      # Module that defines methods to be used by instances using
      # ActiveModel::Validations
      # The name is ActiveRecordExtension in order to not break backwards
      # compatibility, although probably it should be named
      # Rollbar::ValidationsExtension or similar
      module ActiveRecordExtension
        def report_validation_errors_to_rollbar
          errors.full_messages.each do |error|
            Rollbar.log_info "[Rollbar] Reporting form validation error: #{error} for #{self}"
            Rollbar.warning("Form Validation Error: #{error} for #{self}")
          end
        end
      end
    end
  end

  execute! do
    ActiveModel::Validations.module_eval do
      include Rollbar::ActiveRecordExtension
    end
  end
end
