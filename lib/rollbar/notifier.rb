require 'rollbar/configuration'
require 'rollbar/lazy_store'
require 'rollbar/util'
require 'rollbar/json'
require 'rollbar/exceptions'
require 'rollbar/language_support'
require 'rollbar/delay/girl_friday'
require 'rollbar/delay/thread'
require 'rollbar/logger_proxy'
require 'rollbar/item'
require 'rollbar/notifier/trace_with_bindings'
require 'ostruct'

module Rollbar
  # The notifier class. It has the core functionality
  # for sending reports to the API.
  class Notifier
    attr_accessor :configuration
    attr_accessor :last_report
    attr_accessor :scope_object

    MUTEX = Mutex.new
    EXTENSION_REGEXP = /.rollbar\z/.freeze

    def initialize(parent_notifier = nil, payload_options = nil, scope = nil)
      if parent_notifier
        self.configuration = parent_notifier.configuration.clone
        self.scope_object = parent_notifier.scope_object.clone

        Rollbar::Util.deep_merge(scope_object, scope) if scope
      else
        self.configuration = ::Rollbar::Configuration.new
        self.scope_object = ::Rollbar::LazyStore.new(scope)
      end

      Rollbar::Util.deep_merge(configuration.payload_options, payload_options) if payload_options
    end

    def reset!
      self.scope_object = ::Rollbar::LazyStore.new({})
    end

    # Similar to configure below, but used only internally within the gem
    # to configure it without initializing any of the third party hooks
    def preconfigure
      yield(configuration.configured_options)
    end

    # Configures the notifier instance
    def configure
      configuration.enabled = true if configuration.enabled.nil?

      yield(configuration.configured_options)
    end

    def reconfigure
      self.configuration = Configuration.new
      configuration.enabled = true

      yield(configuration.configured_options)
    end

    def unconfigure
      self.configuration = nil
    end

    def scope(scope_overrides = {}, config_overrides = {})
      new_notifier = self.class.new(self, nil, scope_overrides)
      new_notifier.configuration = configuration.merge(config_overrides)

      new_notifier
    end

    def scope!(options = {}, config_overrides = {})
      Rollbar::Util.deep_merge(scope_object, options)
      configuration.merge!(config_overrides)

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
    rescue StandardError => e
      e.instance_variable_set(:@_rollbar_do_not_report, true)
      raise
    end

    # Sends a report to Rollbar.
    #
    # Accepts a level string plus any number of arguments. The last String
    # argument will become the message or description of the report. The last
    # Exception argument will become the associated exception for the report.
    # The last hash argument will be used as the extra data for the report.
    #
    # If the extra hash contains a symbol key :custom_data_method_context
    # the value of the key will be used as the context for
    # configuration.custom_data_method and will be removed from the extra
    # hash.
    #
    # @example
    #   begin
    #     foo = bar
    #   rescue => e
    #     Rollbar.log('error', e)
    #   end
    #
    # @example
    #   Rollbar.log('info', 'This is a simple log message')
    #
    # @example
    #   Rollbar.log('error', e, 'This is a description of the exception')
    #
    def log(level, *args)
      return 'disabled' unless enabled?

      message, exception, extra, context = extract_arguments(args)
      use_exception_level_filters = use_exception_level_filters?(extra)

      return 'ignored' if ignored?(exception, use_exception_level_filters)

      begin
        status = call_before_process(:level => level,
                                     :exception => exception,
                                     :message => message,
                                     :extra => extra)
        return 'ignored' if status == 'ignored'
      rescue Rollbar::Ignore
        return 'ignored'
      end

      level = lookup_exception_level(level, exception,
                                     use_exception_level_filters)

      ret = report_with_rescue(level, message, exception, extra, context)

      raise(exception) if configuration.raise_on_error && exception

      ret
    end

    def report_with_rescue(level, message, exception, extra, context)
      report(level, message, exception, extra, context)
    rescue StandardError, SystemStackError => e
      report_internal_error(e)

      'error'
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

    def enabled?
      # Require access_token so we don't try to send events when unconfigured.
      configuration.enabled && configuration.access_token && !configuration.access_token.empty?
    end

    def process_item(item)
      if configuration.write_to_file
        if configuration.use_async
          MUTEX.synchronize do
            do_write_item(item)
          end
        else
          do_write_item(item)
        end
      else
        send_item(item)
      end
    rescue StandardError => e
      log_error("[Rollbar] Error processing the item: #{e.class}, #{e.message}. Item: #{item.payload.inspect}")
      raise e unless via_failsafe?(item)

      log_error('[Rollbar] Item has already failed. Not re-raising')
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
      Rollbar.silenced do
        begin
          if payload.is_a?(String)
            # The final payload has already been built.
            send_body(payload)
          else
            item = Item.build_with(payload,
                                   :notifier => self,
                                   :configuration => configuration,
                                   :logger => logger)

            process_item(item)
          end
        rescue StandardError => e
          report_internal_error(e)

          raise
        end
      end
    end

    def send_failsafe(message, exception, uuid = nil, host = nil)
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
        :custom => {
          :orig_uuid => uuid,
          :orig_host => host
        },
        :internal => true,
        'failsafe' => true
      }

      failsafe_payload = {
        'data' => failsafe_data
      }

      begin
        item = Item.build_with(failsafe_payload,
                               :notifier => self,
                               :configuration => configuration,
                               :logger => logger)
        schedule_item(item)
      rescue StandardError => e
        log_error "[Rollbar] Error sending failsafe : #{e}"
      end

      failsafe_payload
    end

    ## Logging
    %w[debug info warn error].each do |level|
      define_method(:"log_#{level}") do |message|
        logger.send(level, message)
      end
    end

    def logger
      @logger ||= LoggerProxy.new(configuration.logger)
    end

    def trace_with_bindings
      @trace_with_bindings ||= TraceWithBindings.new
    end

    def exception_bindings
      trace_with_bindings.exception_frames
    end

    def current_bindings
      trace_with_bindings.frames
    end

    def enable_locals?
      configuration.locals[:enabled] && [:app, :all].include?(configuration.send_extra_frame_data)
    end

    def enable_locals
      trace_with_bindings.enable if enable_locals?
    end

    def disable_locals
      trace_with_bindings.disable if enable_locals?
    end

    private

    def use_exception_level_filters?(options)
      option_value = options && options.delete(:use_exception_level_filters)

      return option_value unless option_value.nil?

      configuration.use_exception_level_filters_default
    end

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
          status = handler.call(options)
          return 'ignored' if status == 'ignored'
        rescue Rollbar::Ignore
          raise
        rescue StandardError => e
          log_error("[Rollbar] Error calling the `before_process` hook: #{e}")

          break
        end
      end
    end

    def extract_arguments(args)
      message = nil
      exception = nil
      extra = nil
      context = nil

      args.each do |arg|
        if arg.is_a?(String)
          message = arg
        elsif arg.is_a?(Exception)
          exception = arg
        elsif RUBY_PLATFORM == 'java' && arg.is_a?(java.lang.Throwable)
          exception = arg
        elsif arg.is_a?(Hash)
          extra = arg

          context = extra[:custom_data_method_context]
          extra.delete :custom_data_method_context

          extra = nil if extra.empty?
        end
      end

      [message, exception, extra, context]
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

    def report(level, message, exception, extra, context)
      unless message || exception || extra
        log_error '[Rollbar] Tried to send a report with no message, exception or extra data.'

        return 'error'
      end

      item = build_item(level, message, exception, extra, context)

      return 'ignored' if item.ignored?

      schedule_item(item) if configuration.transmit

      log_and_return_item_data(item)
    end

    def log_and_return_item_data(item)
      data = item['data']
      log_instance_link(data)
      Rollbar.last_report = data
      log_data(data) if configuration.log_payload

      data
    end

    def log_data(data)
      log_info "[Rollbar] Data: #{data}"
    end

    # Reports an internal error in the Rollbar library. This will be reported within the configured
    # Rollbar project. We'll first attempt to provide a report including the exception traceback.
    # If that fails, we'll fall back to a more static failsafe response.
    def report_internal_error(exception)
      log_error '[Rollbar] Reporting internal error encountered while sending data to Rollbar.'

      configuration.execute_hook(:on_report_internal_error, exception)

      begin
        item = build_item('error', nil, exception, { :internal => true }, nil)
      rescue StandardError => e
        send_failsafe('build_item in exception_data', e)
        log_error "[Rollbar] Exception: #{exception}"
        return
      end

      begin
        process_item(item)
      rescue StandardError => e
        send_failsafe('error in process_item', e)
        log_error "[Rollbar] Item: #{item}"
        return
      end

      begin
        log_instance_link(item['data'])
      rescue StandardError => e
        send_failsafe('error logging instance link', e)
        log_error "[Rollbar] Item: #{item}"
        return
      end
    end

    ## Payload building functions

    def build_item(level, message, exception, extra, context)
      options = {
        :level => level,
        :message => message,
        :exception => exception,
        :extra => extra,
        :configuration => configuration,
        :logger => logger,
        :scope => scope_object,
        :notifier => self,
        :context => context
      }

      item = Item.new(options)
      item.build

      item
    end

    ## Delivery functions

    def send_using_eventmachine(body)
      uri = URI.parse(configuration.endpoint)

      headers = { 'X-Rollbar-Access-Token' => configuration.access_token }
      options = http_proxy_for_em(uri)
      req = EventMachine::HttpRequest.new(uri.to_s, options).post(:body => body, :head => headers)

      eventmachine_callback(req)
      eventmachine_errback(req)
    end

    def eventmachine_callback(req)
      req.callback do
        if req.response_header.status == 200
          log_info '[Rollbar] Success'
        else
          log_warning "[Rollbar] Got unexpected status code from Rollbar.io api: #{req.response_header.status}"
          log_info "[Rollbar] Response: #{req.response}"
        end
      end
    end

    def eventmachine_errback(req)
      req.errback do
        log_warning "[Rollbar] Call to API failed, status code: #{req.response_header.status}"
        log_info "[Rollbar] Error's response: #{req.response}"
      end
    end

    def send_item(item)
      log_info '[Rollbar] Sending item'

      body = item.dump
      return unless body

      if configuration.use_eventmachine
        send_using_eventmachine(body)
        return
      end

      send_body(body)
    end

    def send_body(body)
      log_info '[Rollbar] Sending json'

      uri = URI.parse(configuration.endpoint)

      handle_response(do_post(uri, body, configuration.access_token))
    end

    def do_post(uri, body, access_token)
      proxy = http_proxy(uri)
      http  = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)

      http.open_timeout = configuration.open_timeout
      http.read_timeout = configuration.request_timeout

      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = ssl_verify_mode
      end

      request = Net::HTTP::Post.new(uri.request_uri)

      request.body = pack_ruby260_bytes(body)
      request.add_field('X-Rollbar-Access-Token', access_token)

      handle_net_retries { http.request(request) }
    end

    def pack_ruby260_bytes(body)
      # Ruby 2.6.0 shipped with a bug affecting multi-byte body for Net::HTTP.
      # Fix (committed one day after 2.6.0p0 shipped) is here:
      # https://github.com/ruby/ruby/commit/1680a13a926b17661329beec1ded6b32aad16c1b#diff-00a99d8c71daaf5fc60a050da41f7261
      #
      # We work around this by repacking the body as single byte chars if needed.
      if RUBY_VERSION == '2.6.0' && multibyte?(body)
        body.unpack('C*').pack('C*')
      else
        body
      end
    end

    def multibyte?(str)
      str.chars.length != str.bytes.length
    end

    def http_proxy_for_em(uri)
      proxy = http_proxy(uri)
      {
        :proxy => {
          :host => proxy.host,
          :port => proxy.port,
          :authorization => [proxy.user, proxy.password]
        }
      }
    end

    def http_proxy(uri)
      @http_proxy ||= proxy_from_config || proxy_from_env(uri) || null_proxy
    end

    def proxy_from_config
      proxy_settings = configuration.proxy
      return nil unless proxy_settings

      proxy = null_proxy
      proxy.host = URI.parse(proxy_settings[:host]).host
      proxy.port = proxy_settings[:port]
      proxy.user = proxy_settings[:user]
      proxy.password = proxy_settings[:password]
      proxy
    end

    def proxy_from_env(uri)
      uri.find_proxy
    end

    def null_proxy
      Struct.new(:host, :port, :user, :password).new
    end

    def handle_net_retries
      return yield if skip_retries?

      retries = configuration.net_retries - 1

      begin
        yield
      rescue *LanguageSupport.timeout_exceptions
        raise if retries <= 0

        retries -= 1

        retry
      end
    end

    def skip_retries?
      Rollbar::LanguageSupport.ruby_19?
    end

    def handle_response(response)
      if response.code == '200'
        log_info '[Rollbar] Success'
      else
        log_warning "[Rollbar] Got unexpected status code from Rollbar api: #{response.code}"
        log_info "[Rollbar] Response: #{response.body}"
        configuration.execute_hook(:on_error_response, response)
      end
    end

    def ssl_verify_mode
      if configuration.verify_ssl_peer
        OpenSSL::SSL::VERIFY_PEER
      else
        OpenSSL::SSL::VERIFY_NONE
      end
    end

    def do_write_item(item)
      log_info '[Rollbar] Writing item to file'

      body = item.dump
      return unless body

      file_name = if configuration.files_with_pid_name_enabled
                    configuration.filepath.gsub(EXTENSION_REGEXP, "_#{Process.pid}\\0")
                  else
                    configuration.filepath
                  end

      begin
        @file ||= File.open(file_name, 'a')

        @file.puts(body)
        @file.flush
        update_file(@file, file_name)

        log_info '[Rollbar] Success'
      rescue IOError => e
        log_error "[Rollbar] Error opening/writing to file: #{e}"
      end
    end

    def update_file(file, file_name)
      return unless configuration.files_processed_enabled

      time_now = Time.now
      return if configuration.files_processed_duration > time_now - file.birthtime && file.size < configuration.files_processed_size

      new_file_name = file_name.gsub(EXTENSION_REGEXP, "_processed_#{time_now.to_i}\\0")
      File.rename(file, new_file_name)
      file.close
      @file = File.open(file_name, 'a')
    end

    def failsafe_reason(message, exception)
      body = ''

      if exception
        begin
          backtrace = exception.backtrace || []
          nearest_frame = backtrace[0]

          exception_info = exception.class.name
          # #to_s and #message defaults to class.to_s. Add message only if add valuable info.
          exception_info += %[: "#{exception.message}"] if exception.message != exception.class.to_s
          exception_info += " in #{nearest_frame}" if nearest_frame

          body += "#{exception_info}: #{message}"
        rescue StandardError
          log_error('[Rollbar] Error building failsafe exception message')
        end
      else
        begin
          body += message.to_s
        rescue StandardError
          log_error('[Rollbar] Error building failsafe message')
        end
      end

      body
    end

    def failsafe_body(reason)
      "Failsafe from rollbar-gem. #{reason}"
    end

    def schedule_item(item)
      return unless item

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
      # Send async payloads as JSON string when async_json_payload is set.
      payload = configuration.async_json_payload ? item.dump : item.payload

      configuration.async_handler ||= default_async_handler
      configuration.async_handler.call(payload)
    rescue StandardError
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
        rescue StandardError
          next unless handler == failover_handlers.last

          log_error "[Rollbar] All failover handlers failed while processing item: #{Rollbar::JSON.dump(item.payload)}"
        end
      end
    end

    alias log_warning log_warn

    def log_instance_link(data)
      return unless data[:uuid]

      uuid_url = Util.uuid_rollbar_url(data, configuration)
      log_info "[Rollbar] Details: #{uuid_url} (only available if report was successful)"
    end

    def via_failsafe?(item)
      item.payload.fetch('data', {}).fetch('failsafe', false)
    end
  end
end
