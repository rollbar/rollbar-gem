require 'net/protocol'
require 'net/https'
require 'socket'
require 'thread'
require 'uri'
require 'forwardable'

begin
  require 'securerandom'
rescue LoadError
end

require 'rollbar/version'
require 'rollbar/plugins'
require 'rollbar/configuration'
require 'rollbar/logger_proxy'
require 'rollbar/exceptions'
require 'rollbar/lazy_store'
require 'rollbar/notifier'

module Rollbar
  PUBLIC_NOTIFIER_METHODS = %w(debug info warn warning error critical log logger
                               process_item process_from_async_handler scope send_failsafe log_info log_debug
                               log_warning log_error silenced)

  class << self
    extend Forwardable

    def_delegators :notifier, *PUBLIC_NOTIFIER_METHODS

    attr_writer :plugins

    # Similar to configure below, but used only internally within the gem
    # to configure it without initializing any of the third party hooks
    def preconfigure
      yield(configuration)

      reset_notifier!
    end

    def configure
      # if configuration.enabled has not been set yet (is still 'nil'), set to true.
      configuration.enabled = true if configuration.enabled.nil?

      yield(configuration)

      plugins.load!
      reset_notifier!
    end

    def reconfigure
      @configuration = Configuration.new
      @configuration.enabled = true
      yield(configuration)

      reset_notifier!
    end

    def unconfigure
      @configuration = nil
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def scope_object
      @scope_obejct ||= ::Rollbar::LazyStore.new({})
    end

    def safely?
      configuration.safely?
    end

    def plugins
      @plugins ||= Rollbar::Plugins.new
    end

    def notifier
      Thread.current[:_rollbar_notifier] ||= Notifier.new(self)
    end

    def notifier=(notifier)
      Thread.current[:_rollbar_notifier] = notifier
    end

    def last_report
      Thread.current[:_rollbar_last_report]
    end

    def last_report=(report)
      Thread.current[:_rollbar_last_report] = report
    end

    def reset_notifier!
      self.notifier = nil
    end

    # Create a new Notifier instance using the received options and
    # set it as the current thread notifier.
    # The calls to Rollbar inside the received block will use then this
    # new Notifier object.
    #
    # @example
    #
    #   new_scope = { job_type: 'scheduled' }
    #   Rollbar.scoped(new_scope) do
    #     begin
    #       # do stuff
    #     rescue => e
    #       Rollbar.log(e)
    #     end
    #   end
    def scoped(options = {})
      old_notifier = notifier
      self.notifier = old_notifier.scope(options)

      result = yield
      result
    ensure
      self.notifier = old_notifier
    end

    def scope!(options = {})
      notifier.scope!(options)
    end

    # Backwards compatibility methods

    def report_exception(exception, request_data = nil, person_data = nil, level = 'error')
      Kernel.warn('[DEPRECATION] Rollbar.report_exception has been deprecated, please use log() or one of the level functions')

      scope = {}
      scope[:request] = request_data if request_data
      scope[:person] = person_data if person_data

      Rollbar.scoped(scope) do
        Rollbar.notifier.log(level, exception, :use_exception_level_filters => true)
      end
    end

    def report_message(message, level = 'info', extra_data = nil)
      Kernel.warn('[DEPRECATION] Rollbar.report_message has been deprecated, please use log() or one of the level functions')

      Rollbar.notifier.log(level, message, extra_data)
    end

    def report_message_with_request(message, level = 'info', request_data = nil, person_data = nil, extra_data = nil)
      Kernel.warn('[DEPRECATION] Rollbar.report_message_with_request has been deprecated, please use log() or one of the level functions')

      scope = {}
      scope[:request] = request_data if request_data
      scope[:person] = person_data if person_data

      Rollbar.scoped(:request => request_data, :person => person_data) do
        Rollbar.notifier.log(level, message, extra_data)
      end
    end
  end
end

Rollbar.plugins.require_all
