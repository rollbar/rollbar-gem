# encoding: utf-8

if Sidekiq::VERSION < '3'
  module Rollbar
    class Sidekiq
      def call(worker, msg, queue)
        begin
          yield
        rescue Exception => e
          msg.delete('backtrace')
          msg.delete('error_backtrace')
          msg.delete('error_message')
          msg.delete('error_class')

          Rollbar.report_exception(e, :params => msg)
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
      context.delete('backtrace')
      context.delete('error_backtrace')
      context.delete('error_message')
      context.delete('error_class')

      Rollbar.report_exception(e, :params => context)
    end
  end
end
