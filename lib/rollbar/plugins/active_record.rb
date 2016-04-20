Rollbar.plugins.define('active_record') do
  dependency { !configuration.disable_monkey_patch }
  dependency { defined?(ActiveRecord) }
  dependency do
    require 'active_record/version'

    ActiveRecord::VERSION::MAJOR >= 3
  end

  execute do
    module Rollbar
      module ActiveRecordExtension
        extend ActiveSupport::Concern

        def report_validation_errors_to_rollbar
          errors.full_messages.each do |error|
            Rollbar.log_info "[Rollbar] Reporting form validation error: #{error} for #{self}"
            Rollbar.warning("Form Validation Error: #{error} for #{self}")
          end
        end
      end
    end
  end

  execute do
    ActiveRecord::Base.class_eval do
      include Rollbar::ActiveRecordExtension
    end
  end
end
