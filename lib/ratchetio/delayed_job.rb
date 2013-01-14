# based on http://bit.ly/VGdfVI

module Delayed
  module Plugins
    class Ratchetio < Plugin
      module ReportErrors
        def error(job, error)
          # send the job object as the 'request data'
          ::Ratchetio.report_exception(error, job)
          super if defined?(super)
        end
      end

      callbacks do |lifecycle|
        lifecycle.before(:invoke_job) do |job|
          payload = job.payload_object
          payload = payload.object if payload.is_a? Delayed::PerformableMethod
          payload.extend ReportErrors
        end
      end
    end
  end
end

Delayed::Worker.plugins << Delayed::Plugins::Ratchetio
