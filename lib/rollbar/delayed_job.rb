# based on http://bit.ly/VGdfVI

module Delayed
  module Plugins
    class Rollbar < Plugin
      callbacks do |lifecycle|
        lifecycle.around(:invoke_job) do |job, *args, &block|
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
end

Delayed::Worker.plugins << Delayed::Plugins::Rollbar
