require 'rollbar/scrubbers/params'

module Rollbar
  class Sidekiq
    PARAM_BLACKLIST = %w[backtrace error_backtrace error_message error_class].freeze

    class ClearScope
      def call(_worker, _msg, _queue)
        Rollbar.reset_notifier!

        yield
      end
    end

    def self.handle_exception(ctx_hash, e)
      job_hash = ctx_hash && (ctx_hash[:job] || ctx_hash)
      return if skip_report?(job_hash, e)

      Rollbar.scope(job_scope(job_hash)).error(e, :use_exception_level_filters => true)
    end

    def self.job_scope(job_hash)
      scope = {
        :framework => "Sidekiq: #{::Sidekiq::VERSION}"
      }
      unless job_hash.nil?
        params = job_hash.reject { |k| PARAM_BLACKLIST.include?(k) }
        scope[:request] = { :params => scrub_params(params) }
        scope[:context] = params['class']
        scope[:queue] = params['queue']
      end

      scope
    end

    def self.scrub_params(params)
      options = {
        :params => params,
        :config => Rollbar.configuration.scrub_fields
      }

      Rollbar::Scrubbers::Params.call(options)
    end

    def self.skip_report?(job_hash, _e)
      return false if job_hash.nil?

      # when rollbar middleware catches, sidekiq's retry_job processor hasn't set
      # the retry_count for the current job yet, so adding 1 gives the actual retry count
      actual_retry_count = job_hash.fetch('retry_count', -1) + 1
      job_hash['retry'] && actual_retry_count < ::Rollbar.configuration.sidekiq_threshold
    end

    def call(_worker, msg, _queue)
      Rollbar.reset_notifier!

      yield
    rescue Exception => e
      Rollbar::Sidekiq.handle_exception(msg, e)
      raise
    end
  end
end
