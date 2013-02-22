# encoding: utf-8

module Rollbar
  class Sidekiq
    def call(worker, msg, queue)
      begin
        yield
      rescue => e
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
