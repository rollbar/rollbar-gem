require 'rollbar/scrubbers/params'

module Rollbar
  class Sidekiq
    PARAM_BLACKLIST = %w[backtrace error_backtrace error_message error_class].freeze

    class ResetScope
      def call(_worker, msg, _queue, &block)
        Rollbar.reset_notifier! # clears scope

        return yield unless Rollbar.configuration.sidekiq_use_scoped_block

        Rollbar.scoped(Rollbar::Sidekiq.job_scope(msg), &block)
      end
    end

    def self.handle_exception(msg, e)
      return if skip_report?(msg, e)

      Rollbar.scope(job_scope(msg)).error(e, :use_exception_level_filters => true)
    end

    def self.skip_report?(msg, _e)
      job_hash = job_hash_from_msg(msg)

      return false if job_hash.nil?
      return false unless job_hash['retry_count'] # This job  is not a retry attempt if retry_count is not set

      # Sidekiq retry_count tracks the number of previous retries attempted, which means that for the first retry,
      # it would be set to 0.
      job_hash['retry_count'] + 1 < ::Rollbar.configuration.sidekiq_threshold
    end

    def self.job_scope(msg)
      scope = {
        :framework => "Sidekiq: #{::Sidekiq::VERSION}"
      }
      job_hash = job_hash_from_msg(msg)

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

    # see https://github.com/mperham/sidekiq/wiki/Middleware#server-middleware
    def call(_worker, msg, _queue, &block)
      Rollbar.reset_notifier! # clears scope

      return yield unless Rollbar.configuration.sidekiq_use_scoped_block

      Rollbar.scoped(Rollbar::Sidekiq.job_scope(msg), &block)
    rescue Exception => e
      Rollbar::Sidekiq.handle_exception(msg, e)
      raise
    end

    def self.job_hash_from_msg(msg)
      msg && (msg[:job] || msg)
    end
    private_class_method :job_hash_from_msg
  end
end
