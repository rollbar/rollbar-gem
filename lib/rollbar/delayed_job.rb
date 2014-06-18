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
            ::Rollbar.report_exception(e, data)
          end
          raise e
        end
      end
    end
  end
end
