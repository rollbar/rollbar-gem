module Rollbar
  module ActiveRecordExtension
    extend ActiveSupport::Concern

    def report_validation_errors_to_rollbar
      self.errors.full_messages.each do |error|
        logger.info "[Rollbar] Reporting form validation error: #{error} for #{self.to_s}"
        Rollbar.report_message("Form Validation Error: #{error} for #{self.to_s}")
      end
    end
  end
end

ActiveRecord::Base.send(:include, Rollbar::ActiveRecordExtension)
