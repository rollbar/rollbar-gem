module Rollbar
  class Sidekiq
    PARAM_BLACKLIST = %w[backtrace error_backtrace error_message error_class]

    class ClearScope
      def call(worker, msg, queue)
        Rollbar.reset_notifier!

        yield
      end
    end

    def self.handle_exception(msg_or_context, e)
      return if skip_report?(msg_or_context, e)

      params = msg_or_context.reject{ |k| PARAM_BLACKLIST.include?(k) }
      scope = {
        :request => { :params => params },
        :framework => "Sidekiq: #{::Sidekiq::VERSION}"
      }
      if params.is_a?(Hash)
        scope[:context] = params['class']
        scope[:queue] = params['queue']
      end

      Rollbar.scope(scope).error(e, :use_exception_level_filters => true)
    end

    def self.skip_report?(msg_or_context, e)
      msg_or_context.is_a?(Hash) && msg_or_context["retry"] &&
        msg_or_context["retry_count"] && msg_or_context["retry_count"] < ::Rollbar.configuration.sidekiq_threshold
    end

    def call(worker, msg, queue)
      Rollbar.reset_notifier!

      yield
    rescue Exception => e
      Rollbar::Sidekiq.handle_exception(msg, e)
      raise
    end
  end
end
