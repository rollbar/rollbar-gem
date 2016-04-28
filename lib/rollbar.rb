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
require 'rollbar/json'
require 'rollbar/js'
require 'rollbar/configuration'
require 'rollbar/item'
require 'rollbar/encoding'
require 'rollbar/logger_proxy'
require 'rollbar/exception_reporter'
require 'rollbar/util'
require 'rollbar/delay/girl_friday' if defined?(GirlFriday)
require 'rollbar/delay/thread'
require 'rollbar/truncation'
require 'rollbar/exceptions'
require 'rollbar/lazy_store'

module Rollbar
  PUBLIC_NOTIFIER_METHODS = %w(debug info warn warning error critical log logger
                               process_item process_from_async_handler scope send_failsafe log_info log_debug
                               log_warning log_error silenced)

  class Notifier
    attr_accessor :configuration
    attr_accessor :last_report
    attr_reader :scope_object

    @file_semaphore = Mutex.new

    def initialize(parent_notifier = nil, item_options = nil, scope = nil)
      if parent_notifier
        @configuration = parent_notifier.configuration.clone
        @scope_object = parent_notifier.scope_object.clone

        Rollbar::Util.deep_merge(@configuration.item_options, item_options) if item_options
        Rollbar::Util.deep_merge(@scope_object, scope) if scope
      else
        @configuration = ::Rollbar::Configuration.new
        @scope_object = ::Rollbar::LazyStore.new(scope)
      end
    end

    # Similar to configure below, but used only internally within the gem
    # to configure it without initializing any of the third party hooks
    def preconfigure
      yield(configuration)
    end

    # Configures the notifier instance
    def configure
      configuration.enabled = true if configuration.enabled.nil?

      yield(configuration)
    end

    def scope(options = {})
      self.class.new(self, nil, options)
    end

    def scope!(options = {})
      Rollbar::Util.deep_merge(scope_object, options)

      self
    end

    # Returns a new notifier with same configuration options
    # but it sets Configuration#safely to true.
    # We are using this flag to avoid having inifite loops
    # when evaluating some custom user methods.
    def safely
      new_notifier = scope
      new_notifier.configuration.safely = true

      new_notifier
    end

    # Turns off reporting for the given block.
    #
    # @example
    #   Rollbar.silenced { raise }
    #
    # @yield Block which exceptions won't be reported.
    def silenced
      yield
    rescue => e
      e.instance_variable_set(:@_rollbar_do_not_report, true)
      raise
    end

    # Sends a report to Rollbar.
    #
    # Accepts any number of arguments. The last String argument will become
    # the message or description of the report. The last Exception argument
    # will become the associated exception for the report. The last hash
    # argument will be used as the extra data for the report.
    #
    # @example
    #   begin
    #     foo = bar
    #   rescue => e
    #     Rollbar.log(e)
    #   end
    #
    # @example
    #   Rollbar.log('This is a simple log message')
    #
    # @example
    #   Rollbar.log(e, 'This is a description of the exception')
    #
    def log(level, *args)
      return 'disabled' unless configuration.enabled

      message, exception, extra = extract_arguments(args)
      use_exception_level_filters = extra && extra.delete(:use_exception_level_filters) == true

      return 'ignored' if ignored?(exception, use_exception_level_filters)

      begin
        call_before_process(:level => level,
                            :exception => exception,
                            :message => message,
                            :extra => extra)
      rescue Rollbar::Ignore
        return 'ignored'
      end

      level = lookup_exception_level(level, exception,
                                     use_exception_level_filters)

      begin
        report(level, message, exception, extra)
      rescue Exception => e
        report_internal_error(e)

        'error'
      end
    end

    # See log() above
    def debug(*args)
      log('debug', *args)
    end

    # See log() above
    def info(*args)
      log('info', *args)
    end

    # See log() above
    def warn(*args)
      log('warning', *args)
    end

    # See log() above
    def warning(*args)
      log('warning', *args)
    end

    # See log() above
    def error(*args)
      log('error', *args)
    end

    # See log() above
    def critical(*args)
      log('critical', *args)
    end

    def process_item(item)
      if configuration.write_to_file
        if configuration.use_async
          @file_semaphore.synchronize {
            write_item(item)
          }
        else
          write_item(item)
        end
      else
        send_item(item)
      end
    rescue => e
      log_error("[Rollbar] Error processing the item: #{e.class}, #{e.message}. Item: #{item.payload.inspect}")
      raise e
    end

    # We will reraise exceptions in this method so async queues
    # can retry the job or, in general, handle an error report some way.
    #
    # At same time that exception is silenced so we don't generate
    # infinite reports. This example is what we want to avoid:
    #
    # 1. New exception in a the project is raised
    # 2. That report enqueued to Sidekiq queue.
    # 3. The Sidekiq job tries to send the report to our API
    # 4. The report fails, for example cause a network failure,
    #    and a exception is raised
    # 5. We report an internal error for that exception
    # 6. We reraise the exception so Sidekiq job fails and
    #    Sidekiq can retry the job reporting the original exception
    # 7. Because the job failed and Sidekiq can be managed by rollbar we'll
    #    report a new exception.
    # 8. Go to point 2.
    #
    # We'll then push to Sidekiq queue indefinitely until the network failure
    # is fixed.
    #
    # Using Rollbar.silenced we avoid the above behavior but Sidekiq
    # will have a chance to retry the original job.
    def process_from_async_handler(payload)
      payload = Rollbar::JSON.load(payload) if payload.is_a?(String)

      item = Item.build_with(payload)

      Rollbar.silenced do
        begin
          process_item(item)
        rescue => e
          report_internal_error(e)

          raise
        end
      end
    end

    private

    def call_before_process(options)
      options = {
        :level => options[:level],
        :scope => scope_object,
        :exception => options[:exception],
        :message => options[:message],
        :extra => options[:extra]
      }
      handlers = configuration.before_process

      handlers.each do |handler|
        begin
          handler.call(options)
        rescue Rollbar::Ignore
          raise
        rescue => e
          log_error("[Rollbar] Error calling the `before_process` hook: #{e}")

          break
        end
      end
    end

    def extract_arguments(args)
      message = nil
      exception = nil
      extra = nil

      args.each do |arg|
        if arg.is_a?(String)
          message = arg
        elsif arg.is_a?(Exception)
          exception = arg
        elsif arg.is_a?(Hash)
          extra = arg
        end
      end

      [message, exception, extra]
    end

    def lookup_exception_level(orig_level, exception, use_exception_level_filters)
      return orig_level unless use_exception_level_filters

      exception_level = filtered_level(exception)
      return exception_level if exception_level

      orig_level
    end

    def ignored?(exception, use_exception_level_filters = false)
      return false unless exception
      return true if use_exception_level_filters && filtered_level(exception) == 'ignore'
      return true if exception.instance_variable_get(:@_rollbar_do_not_report)

      false
    end

    def filtered_level(exception)
      return unless exception

      filter = configuration.exception_level_filters[exception.class.name]
      if filter.respond_to?(:call)
        filter.call(exception)
      else
        filter
      end
    end

    def report(level, message, exception, extra)
      unless message || exception || extra
        log_error '[Rollbar] Tried to send a report with no message, exception or extra data.'

        return 'error'
      end

      item = build_item(level, message, exception, extra)

      return 'ignored' if item.ignored?

      schedule_item(item)

      data = item['data']
      log_instance_link(data)
      Rollbar.last_report = data

      data
    end

    # Reports an internal error in the Rollbar library. This will be reported within the configured
    # Rollbar project. We'll first attempt to provide a report including the exception traceback.
    # If that fails, we'll fall back to a more static failsafe response.
    def report_internal_error(exception)
      log_error "[Rollbar] Reporting internal error encountered while sending data to Rollbar."

      begin
        item = build_item('error', nil, exception, {:internal => true})
      rescue => e
        send_failsafe("build_item in exception_data", e)
        return
      end

      begin
        process_item(item)
      rescue => e
        send_failsafe("error in process_item", e)
        return
      end

      begin
        log_instance_link(item['data'])
      rescue => e
        send_failsafe("error logging instance link", e)
        return
      end
    end

    ## Payload building functions

    def build_item(level, message, exception, extra)
      options = {
        :level => level,
        :message => message,
        :exception => exception,
        :extra => extra,
        :configuration => configuration,
        :logger => logger,
        :scope => scope_object,
        :notifier => self
      }

      item = Item.new(options)
      item.build

      item
    end

    ## Delivery functions

    def send_item_using_eventmachine(item)
      body = dump_item(item)
      headers = { 'X-Rollbar-Access-Token' => item['access_token'] }
      req = EventMachine::HttpRequest.new(configuration.endpoint).post(:body => body, :head => headers)

      req.callback do
        if req.response_header.status == 200
          log_info '[Rollbar] Success'
        else
          log_warning "[Rollbar] Got unexpected status code from Rollbar.io api: #{req.response_header.status}"
          log_info "[Rollbar] Response: #{req.response}"
        end
      end

      req.errback do
        log_warning "[Rollbar] Call to API failed, status code: #{req.response_header.status}"
        log_info "[Rollbar] Error's response: #{req.response}"
      end
    end

    def send_item(item)
      log_info '[Rollbar] Sending item'

      if configuration.use_eventmachine
        send_item_using_eventmachine(item)
        return
      end

      body = dump_item(item)

      uri = URI.parse(configuration.endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = configuration.request_timeout

      if uri.scheme == 'https'
        http.use_ssl = true
        # This is needed to have 1.8.7 passing tests
        http.ca_file = ENV['ROLLBAR_SSL_CERT_FILE'] if ENV.has_key?('ROLLBAR_SSL_CERT_FILE')
        http.verify_mode = ssl_verify_mode
      end

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = body
      request.add_field('X-Rollbar-Access-Token', item['access_token'])
      response = http.request(request)

      if response.code == '200'
        log_info '[Rollbar] Success'
      else
        log_warning "[Rollbar] Got unexpected status code from Rollbar api: #{response.code}"
        log_info "[Rollbar] Response: #{response.body}"
      end
    end

    def ssl_verify_mode
      if configuration.verify_ssl_peer
        OpenSSL::SSL::VERIFY_PEER
      else
        OpenSSL::SSL::VERIFY_NONE
      end
    end

    def write_item(item)
      if configuration.use_async
        @file_semaphore.synchronize {
          do_write_item(item)
        }
      else
        do_write_item(item)
      end
    end

    def do_write_item(item)
      log_info '[Rollbar] Writing item to file'

      body = dump_item(item)

      begin
        unless @file
          @file = File.open(configuration.filepath, "a")
        end

        @file.puts(body)
        @file.flush
        log_info "[Rollbar] Success"
      rescue IOError => e
        log_error "[Rollbar] Error opening/writing to file: #{e}"
      end
    end

    def send_failsafe(message, exception)
      exception_reason = failsafe_reason(message, exception)

      log_error "[Rollbar] Sending failsafe response due to #{exception_reason}"

      body = failsafe_body(exception_reason)

      failsafe_data = {
        :level => 'error',
        :environment => configuration.environment.to_s,
        :body => {
          :message => {
            :body => body
          }
        },
        :notifier => {
          :name => 'rollbar-gem',
          :version => VERSION
        },
        :internal => true,
        :failsafe => true
      }

      failsafe_payload = {
        'access_token' => configuration.access_token,
        'data' => failsafe_data
      }

      begin
        schedule_item(Item.build_with(failsafe_payload))
      rescue => e
        log_error "[Rollbar] Error sending failsafe : #{e}"
      end

      failsafe_payload
    end

    def failsafe_reason(message, exception)
      body = ''

      if exception
        begin
          backtrace = exception.backtrace || []
          nearest_frame = backtrace[0]

          exception_info = exception.class.name
          # #to_s and #message defaults to class.to_s. Add message only if add valuable info.
          exception_info += %Q{: "#{exception.message}"} if exception.message != exception.class.to_s
          exception_info += " in #{nearest_frame}" if nearest_frame

          body += "#{exception_info}: #{message}"
        rescue
        end
      else
        begin
          body += message.to_s
        rescue
        end
      end

      body
    end

    def failsafe_body(reason)
      "Failsafe from rollbar-gem. #{reason}"
    end

    def schedule_item(item)
      return if item.nil?

      log_info '[Rollbar] Scheduling item'

      if configuration.use_async
        process_async_item(item)
      else
        process_item(item)
      end
    end

    def default_async_handler
      return Rollbar::Delay::GirlFriday if defined?(GirlFriday)

      Rollbar::Delay::Thread
    end

    def process_async_item(item)
      configuration.async_handler ||= default_async_handler
      configuration.async_handler.call(item.payload)
    rescue => e
      if configuration.failover_handlers.empty?
        log_error '[Rollbar] Async handler failed, and there are no failover handlers configured. See the docs for "failover_handlers"'
        return
      end

      async_failover(item)
    end

    def async_failover(item)
      log_warning '[Rollbar] Primary async handler failed. Trying failovers...'

      failover_handlers = configuration.failover_handlers

      failover_handlers.each do |handler|
        begin
          handler.call(item.payload)
        rescue
          next unless handler == failover_handlers.last

          log_error "[Rollbar] All failover handlers failed while processing item: #{Rollbar::JSON.dump(item.payload)}"
        end
      end
    end

    def dump_item(item)
      payload = item.payload
      # Ensure all keys are strings since we can receive the payload inline or
      # from an async handler job, which can be serialized.
      stringified_payload = Rollbar::Util::Hash.deep_stringify_keys(payload)
      result = Truncation.truncate(stringified_payload)
      return result unless Truncation.truncate?(result)

      original_size = Rollbar::JSON.dump(payload).bytesize
      final_size = result.bytesize
      send_failsafe("Could not send payload due to it being too large after truncating attempts. Original size: #{original_size} Final size: #{final_size}", nil)
      log_error "[Rollbar] Payload too large to be sent: #{Rollbar::JSON.dump(payload)}"

      nil
    end

    ## Logging
    %w(debug info warn error).each do |level|
      define_method(:"log_#{level}") do |message|
        logger.send(level, message)
      end
    end

    alias_method :log_warning, :log_warn

    def log_instance_link(data)
      if data[:uuid]
        uuid_url = Util.uuid_rollbar_url(data, configuration)
        log_info "[Rollbar] Details: #{uuid_url} (only available if report was successful)"
      end
    end

    def logger
      @logger ||= LoggerProxy.new(configuration.logger)
    end
  end

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
