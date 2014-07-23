# encoding: utf-8

PARAM_BLACKLIST = ['backtrace', 'error_backtrace', 'error_message', 'error_class']

if Sidekiq::VERSION < '3'
  module Rollbar
    class Sidekiq
      def call(worker, msg, queue)
        begin
          yield
        rescue Exception => e
          params = msg.reject{ |k| PARAM_BLACKLIST.include?(k) }

          Rollbar.report_exception(e, :params => params)
          raise
        end
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
      
      Rollbar.report_exception(e, :params => params)
    end
  end
end
