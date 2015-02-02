# encoding: utf-8

module Rollbar
  class Sidekiq
    PARAM_BLACKLIST = %w[backtrace error_backtrace error_message error_class]

    def self.handle_exception(msg_or_context, e)
      params = msg_or_context.reject{ |k| PARAM_BLACKLIST.include?(k) }
      scope = { :request => { :params => params } }

      Rollbar.scope(scope).error(e, :use_exception_level_filters => true)
    end

    def call(worker, msg, queue)
      yield
    rescue Exception => e
      Rollbar::Sidekiq.handle_exception(msg, e)
      raise
    end
  end
end

Sidekiq.configure_server do |config|
  if Sidekiq::VERSION < '3'
    config.server_middleware do |chain|
      chain.add Rollbar::Sidekiq
    end
  else
    config.error_handlers << Proc.new do |e, context|
      Rollbar::Sidekiq.handle_exception(context, e)
    end
  end
end
