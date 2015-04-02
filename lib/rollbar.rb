require 'net/https'
require 'socket'
require 'thread'
require 'uri'
require 'multi_json'
require 'forwardable'

begin
  require 'securerandom'
rescue LoadError
end

require 'rollbar/version'
require 'rollbar/configuration'
require 'rollbar/logger_proxy'
require 'rollbar/exception_reporter'
require 'rollbar/util'
require 'rollbar/railtie' if defined?(Rails::VERSION)
require 'rollbar/delay/girl_friday'
require 'rollbar/delay/thread'
require 'rollbar/truncation'

unless ''.respond_to? :encode
  require 'iconv'
end

module Rollbar
  ATTACHMENT_CLASSES = %w[
    ActionDispatch::Http::UploadedFile
    Rack::Multipart::UploadedFile
  ].freeze
  PUBLIC_NOTIFIER_METHODS = %w(debug info warn warning error critical log logger
                               process_payload process_payload_safely scope send_failsafe log_info log_debug
                               log_warning log_error silenced)

  class Notifier
    attr_accessor :configuration

    def initialize(parent_notifier = nil, payload_options = nil)
      if parent_notifier
        @configuration = parent_notifier.configuration.clone

        if payload_options
          Rollbar::Util.deep_merge(@configuration.payload_options, payload_options)
        end
      else
        @configuration = ::Rollbar::Configuration.new
      end
    end

    attr_writer :configuration
    attr_accessor :last_report

    @file_semaphore = Mutex.new

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
      self.class.new(self, options)
    end

    def scope!(options = {})
      Rollbar::Util.deep_merge(@configuration.payload_options, options)
      self
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

      use_exception_level_filters = extra && extra.delete(:use_exception_level_filters) == true

      return 'ignored' if ignored?(exception, use_exception_level_filters)

      if use_exception_level_filters
        exception_level = filtered_level(exception)
        level = exception_level if exception_level
      end

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

    def process_payload(payload)
      if configuration.write_to_file
        if configuration.use_async
          @file_semaphore.synchronize {
            write_payload(payload)
          }
        else
          write_payload(payload)
        end
      else
        send_payload(payload)
      end
    rescue => e
      log_error("[Rollbar] Error processing the payload: #{e.class}, #{e.message}. Payload: #{payload.inspect}")
      raise e
    end

    def process_payload_safely(payload)
      process_payload(payload)
    rescue => e
      report_internal_error(e)
    end

    private

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
        log_error "[Rollbar] Tried to send a report with no message, exception or extra data."
        return 'error'
      end

      payload = build_payload(level, message, exception, extra)
      data = payload['data']

      if data[:person]
        person_id = data[:person][configuration.person_id_method.to_sym]
        return 'ignored' if configuration.ignored_person_ids.include?(person_id)
      end

      schedule_payload(payload)

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
        payload = build_payload('error', nil, exception, {:internal => true})
      rescue => e
        send_failsafe("build_payload in exception_data", e)
        return
      end

      begin
        process_payload(payload)
      rescue => e
        send_failsafe("error in process_payload", e)
        return
      end

      begin
        log_instance_link(payload['data'])
      rescue => e
        send_failsafe("error logging instance link", e)
        return
      end
    end

    ## Payload building functions

    def build_payload(level, message, exception, extra)
      environment = configuration.environment
      environment = 'unspecified' if environment.nil? || environment.empty?

      data = {
        :timestamp => Time.now.to_i,
        :environment => environment,
        :level => level,
        :language => 'ruby',
        :framework => configuration.framework,
        :server => server_data,
        :notifier => {
          :name => 'rollbar-gem',
          :version => VERSION
        }
      }

      data[:body] = build_payload_body(message, exception, extra)
      data[:project_package_paths] = configuration.project_gem_paths if configuration.project_gem_paths
      data[:code_version] = configuration.code_version if configuration.code_version
      data[:uuid] = SecureRandom.uuid if defined?(SecureRandom) && SecureRandom.respond_to?(:uuid)

      Rollbar::Util.deep_merge(data, configuration.payload_options)

      data[:person] = data[:person].call if data[:person].respond_to?(:call)
      data[:request] = data[:request].call if data[:request].respond_to?(:call)
      data[:context] = data[:context].call if data[:context].respond_to?(:call)

      # Our API doesn't allow null context values, so just delete
      # the key if value is nil.
      data.delete(:context) unless data[:context]

      payload = {
        'access_token' => configuration.access_token,
        'data' => data
      }

      enforce_valid_utf8(payload)

      payload
    end

    def build_payload_body(message, exception, extra)
      unless configuration.custom_data_method.nil?
        custom = Rollbar::Util.deep_copy(configuration.custom_data_method.call)
        extra = Rollbar::Util.deep_merge(custom, extra || {})
      end

      if exception
        build_payload_body_exception(message, exception, extra)
      else
        build_payload_body_message(message, extra)
      end
    end

    def build_payload_body_exception(message, exception, extra)
      traces = trace_chain(exception)

      traces[0][:exception][:description] = message if message
      traces[0][:extra] = extra if extra

      if traces.size > 1
        { :trace_chain => traces }
      elsif traces.size == 1
        { :trace => traces[0] }
      end
    end

    def trace_data(exception)
      frames = exception_backtrace(exception).map do |frame|
        # parse the line
        match = frame.match(/(.*):(\d+)(?::in `([^']+)')?/)

        if match
          { :filename => match[1], :lineno => match[2].to_i, :method => match[3] }
        else
          { :filename => "<unknown>", :lineno => 0, :method => frame }
        end
      end

        # reverse so that the order is as rollbar expects
      frames.reverse!

      {
        :frames => frames,
        :exception => {
          :class => exception.class.name,
          :message => exception.message
        }
      }
    end

    # Returns the backtrace to be sent to our API. There are 3 options:
    #
    # 1. The exception received has a backtrace, then that backtrace is returned.
    # 2. configuration.populate_empty_backtraces is disabled, we return [] here
    # 3. The user has configuration.populate_empty_backtraces is enabled, then:
    #
    # We want to send the caller as backtrace, but the first lines of that array
    # are those from the user's Rollbar.error line until this method. We want
    # to remove those lines.
    def exception_backtrace(exception)
      return exception.backtrace if exception.backtrace.respond_to?( :map )
      return [] unless configuration.populate_empty_backtraces

      caller_backtrace = caller
      caller_backtrace.shift while caller_backtrace[0].include?(rollbar_lib_gem_dir)
      caller_backtrace
    end

    def rollbar_lib_gem_dir
      Gem::Specification.find_by_name('rollbar').gem_dir + '/lib'
    end

    def trace_chain(exception)
      traces = [trace_data(exception)]
      visited = [exception]

      while exception.respond_to?(:cause) && (cause = exception.cause) && !visited.include?(cause)
        traces << trace_data(cause)
        visited << cause
        exception = cause
      end

      traces
    end

    def build_payload_body_message(message, extra)
      result = { :body => message || 'Empty message'}
      result[:extra] = extra if extra

      { :message => result }
    end

    def server_data
      data = {
        :host => Socket.gethostname
      }
      data[:root] = configuration.root.to_s if configuration.root
      data[:branch] = configuration.branch if configuration.branch
      data[:pid] = Process.pid

      data
    end

    def enforce_valid_utf8(payload)
      normalizer = lambda do |object|
        is_symbol = object.is_a?(Symbol)

        return object unless object == object.to_s || is_symbol

        value = object.to_s

        if value.respond_to? :encode
          options = { :invalid => :replace, :undef => :replace, :replace => '' }
          ascii_encodings = [Encoding.find('US-ASCII'), Encoding.find('ASCII-8BIT')]

          args = ['UTF-8']
          args << 'binary' if ascii_encodings.include?(value.encoding)
          args << options

          encoded_value = value.encode(*args)
        else
          encoded_value = ::Iconv.conv('UTF-8//IGNORE', 'UTF-8', value)
        end

        is_symbol ? encoded_value.to_sym : encoded_value
      end

      Rollbar::Util.iterate_and_update(payload, normalizer)
    end

    # Walks the entire payload and truncates string values that
    # are longer than the byte_threshold
    def truncate_payload(payload, byte_threshold)
      truncator = proc do |value|
        if value.is_a?(String) && value.bytesize > byte_threshold
          Rollbar::Util.truncate(value, byte_threshold)
        else
          value
        end
      end

      Rollbar::Util.iterate_and_update(payload, truncator)
    end

    ## Delivery functions

    def send_payload_using_eventmachine(payload)
      body = dump_payload(payload)
      headers = { 'X-Rollbar-Access-Token' => payload['access_token'] }
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

    def send_payload(payload)
      log_info '[Rollbar] Sending payload'
      payload = MultiJson.load(payload) if payload.is_a?(String)

      if configuration.use_eventmachine
        send_payload_using_eventmachine(payload)
        return
      end

      body = dump_payload(payload)

      uri = URI.parse(configuration.endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = configuration.request_timeout

      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = body
      request.add_field('X-Rollbar-Access-Token', payload['access_token'])
      response = http.request(request)

      if response.code == '200'
        log_info '[Rollbar] Success'
      else
        log_warning "[Rollbar] Got unexpected status code from Rollbar api: #{response.code}"
        log_info "[Rollbar] Response: #{response.body}"
      end
    end

    def write_payload(payload)
      if configuration.use_async
        @file_semaphore.synchronize {
          do_write_payload(payload)
        }
      else
        do_write_payload(payload)
      end
    end

    def do_write_payload(payload)
      log_info '[Rollbar] Writing payload to file'

      body = dump_payload(payload)

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
      log_error "[Rollbar] Sending failsafe response due to #{message}."
      if exception
        begin
          log_error "[Rollbar] #{exception.class.name}: #{exception}"
        rescue => e
        end
      end

      config = configuration
      environment = config.environment

      failsafe_data = {
        :level => 'error',
        :environment => environment.to_s,
        :body => {
          :message => {
            :body => "Failsafe from rollbar-gem: #{message}"
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
        schedule_payload(failsafe_payload)
      rescue => e
        log_error "[Rollbar] Error sending failsafe : #{e}"
      end
    end

    def schedule_payload(payload)
      return if payload.nil?

      log_info '[Rollbar] Scheduling payload'

      if configuration.use_async
        process_async_payload(payload)
      else
        process_payload(payload)
      end
    end

    def default_async_handler
      return Rollbar::Delay::GirlFriday if defined?(GirlFriday)

      Rollbar::Delay::Thread
    end

    def process_async_payload(payload)
      configuration.async_handler ||= default_async_handler
      configuration.async_handler.call(payload)
    rescue => e
      if configuration.failover_handlers.empty?
        log_error '[Rollbar] Async handler failed, and there are no failover handlers configured. See the docs for "failover_handlers"'
        return
      end

      async_failover(payload)
    end

    def async_failover(payload)
      log_warning '[Rollbar] Primary async handler failed. Trying failovers...'

      failover_handlers = configuration.failover_handlers

      failover_handlers.each do |handler|
        begin
          handler.call(payload)
        rescue
          next unless handler == failover_handlers.last

          log_error "[Rollbar] All failover handlers failed while processing payload: #{MultiJson.dump(payload)}"
        end
      end
    end

    def dump_payload(payload)
      # Ensure all keys are strings since we can receive the payload inline or
      # from an async handler job, which can be serialized.
      stringified_payload = Rollbar::Util::Hash.deep_stringify_keys(payload)
      result = Truncation.truncate(stringified_payload)
      return result unless Truncation.truncate?(result)

      original_size = MultiJson.dump(payload).bytesize
      final_size = result.bytesize
      send_failsafe("Could not send payload due to it being too large after truncating attempts. Original size: #{original_size} Final size: #{final_size}", nil)
      log_error "[Rollbar] Payload too large to be sent: #{MultiJson.dump(payload)}"

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
        log_info "[Rollbar] Details: #{configuration.web_base}/instance/uuid?uuid=#{data[:uuid]} (only available if report was successful)"
      end
    end

    def logger
      @logger ||= LoggerProxy.new(configuration.logger)
    end
  end

  class << self
    extend Forwardable

    def_delegators :notifier, *PUBLIC_NOTIFIER_METHODS

    # Similar to configure below, but used only internally within the gem
    # to configure it without initializing any of the third party hooks
    def preconfigure
      yield(configuration)
    end

    def configure
      # if configuration.enabled has not been set yet (is still 'nil'), set to true.
      configuration.enabled = true if configuration.enabled.nil?

      yield(configuration)

      require_hooks
      # This monkey patch is always needed in order
      # to use Rollbar.scoped
      require 'rollbar/core_ext/thread'

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

    def require_hooks
      return if configuration.disable_monkey_patch
      wrap_delayed_worker

      require 'rollbar/active_record_extension' if defined?(ActiveRecord)
      require 'rollbar/sidekiq' if defined?(Sidekiq)
      require 'rollbar/goalie' if defined?(Goalie)
      require 'rollbar/rack' if defined?(Rack)
      require 'rollbar/rake' if defined?(Rake)
      require 'rollbar/better_errors' if defined?(BetterErrors)
    end

    def wrap_delayed_worker
      return unless defined?(Delayed) && defined?(Delayed::Worker) && configuration.delayed_job_enabled

      require 'rollbar/delayed_job'
      Rollbar::Delayed.wrap_worker
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
