require 'delayed_job'

module Rollbar
  module Delayed
    class << self
      attr_accessor :wrapped
    end

    class JobData
      attr_reader :job

      def initialize(job)
        @job = job
      end

      def to_hash
        job_data = job.as_json
        # Here job_data['handler'] is a YAML object comming
        # from the storage backend
        job_data['handler'] = job.payload_object.as_json

        job_data
      end
    end

    self.wrapped = false

    def self.wrap_worker
      return if wrapped

      around_invoke_job(&invoke_job_callback)

      self.wrapped = true
    end

    def self.wrap_worker!
      self.wrapped = false

      wrap_worker
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

      data = build_job_data(job)

      ::Rollbar.scope(:request => data).error(e, :use_exception_level_filters => true)
    end

    def self.build_job_data(job)
      return nil unless ::Rollbar.configuration.report_dj_data

      JobData.new(job).to_hash
    end
  end
end
