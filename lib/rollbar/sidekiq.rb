# encoding: utf-8

PARAM_BLACKLIST = %w[backtrace error_backtrace error_message error_class]

if Sidekiq::VERSION < '3'
  module Rollbar
    class Sidekiq
      def call(worker, msg, queue)
        yield
      rescue Exception => e
        params = msg.reject{ |k| PARAM_BLACKLIST.include?(k) }
        scope = { :request => { :params => params } }

        Rollbar.scope(scope).error(e, :use_exception_level_filters => true)
        raise
      end
    end
  end

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Rollbar::Sidekiq
    end
  end
else
  Sidekiq.configure_server do |config|
    config.error_handlers << Proc.new do |e, context|
      params = context.reject{ |k| PARAM_BLACKLIST.include?(k) }
      scope = { :request => { :params => params } }

      Rollbar.scope(scope).error(e, :use_exception_level_filters => true)
    end
  end
end
