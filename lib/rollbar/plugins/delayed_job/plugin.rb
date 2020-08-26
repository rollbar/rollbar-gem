require 'delayed_job'
require 'rollbar/plugins/delayed_job/job_data'

module Rollbar
  module Delayed
    class << self
      attr_accessor :wrapped
    end

    class RollbarPlugin < ::Delayed::Plugin
      callbacks do |lifecycle|
        lifecycle.around(:invoke_job, &Delayed.invoke_job_callback)
        lifecycle.after(:failure) do |_, job, _, _|
          data = Rollbar::Delayed.build_job_data(job)

          # DelayedJob < 4.1 doesn't provide job#error
          if job.class.method_defined? :error
            ::Rollbar.scope(:request => data).error(job.error, :use_exception_level_filters => true) if job.error
          elsif job.last_error
            ::Rollbar.scope(:request => data).error("Job has failed and won't be retried anymore: " + job.last_error, :use_exception_level_filters => true)
          end
        end
      end
    end

    self.wrapped = false

    def self.wrap_worker
      return if wrapped

      ::Delayed::Worker.plugins << RollbarPlugin

      self.wrapped = true
    end

    def self.wrap_worker!
      self.wrapped = false

      wrap_worker
    end

    def self.invoke_job_callback
      proc do |job, *args, &block|
        begin
          block.call(job, *args)
        rescue StandardError => e
          report(e, job)

          raise e
        end
      end
    end

    def self.report(e, job)
      return if skip_report?(job)

      data = build_job_data(job)

      ::Rollbar.scope(:request => data).error(e, :use_exception_level_filters => true)
    end

    def self.skip_report?(job)
      handler = ::Rollbar.configuration.async_skip_report_handler

      return handler.call(job) if handler.respond_to?(:call)

      job.attempts < ::Rollbar.configuration.dj_threshold
    end

    def self.build_job_data(job)
      return nil unless ::Rollbar.configuration.report_dj_data

      JobData.new(job).to_hash
    end
  end
end
