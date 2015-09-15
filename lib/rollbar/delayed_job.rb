module Rollbar
  module Delayed
    class << self
      attr_accessor :wrapped
    end

    self.wrapped = false

    def self.wrap_worker
      return if wrapped

      around_invoke_job(&invoke_job_callback)

      self.wrapped = true
    end

    def self.around_invoke_job(&block)
      ::Delayed::Worker.lifecycle.around(:invoke_job, &block)
    end

    def self.invoke_job_callback
      proc do |job, *args, &block|
        begin
          block.call(job, *args)
        rescue => e
          report(e, job)

          raise e
        end
      end
    end

    def self.report(e, job)
      return unless job.attempts <= ::Rollbar.configuration.dj_threshold

      job_data = job.as_json
      data = ::Rollbar.configuration.report_dj_data ? job_data : nil

      ::Rollbar.scope(:request => data).error(e, :use_exception_level_filters => true)
    end
  end
end
