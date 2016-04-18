# encoding: utf-8

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
      scope[:context] = "sidekiq##{params['queue']}" if params.is_a?(Hash)

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

Sidekiq.configure_server do |config|
  if Sidekiq::VERSION.split('.')[0].to_i < 3
    config.server_middleware do |chain|
      chain.add Rollbar::Sidekiq
    end
  else
    config.server_middleware do |chain|
      chain.add Rollbar::Sidekiq::ClearScope
    end

    config.error_handlers << proc do |e, context|
      Rollbar::Sidekiq.handle_exception(context, e)
    end
  end
end
