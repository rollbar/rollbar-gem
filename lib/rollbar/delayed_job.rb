module Rollbar
  module Delayed
    def self.wrap_worker
      return if @wrapped
      @wrapped = true

      ::Delayed::Worker.lifecycle.around(:invoke_job) do |job, *args, &block|
        begin
          block.call(job, *args)
        rescue Exception => e
          if job.attempts >= ::Rollbar.configuration.dj_threshold
            data = ::Rollbar.configuration.report_dj_data ? job : nil
            ::Rollbar.scope(:request => data).error(e, :use_exception_level_filters => true)
          end
          raise e
        end
      end
    end
  end
end
