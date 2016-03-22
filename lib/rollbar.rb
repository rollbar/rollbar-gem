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
require 'rollbar/json'
require 'rollbar/js'
require 'rollbar/configuration'
require 'rollbar/encoding'
require 'rollbar/logger_proxy'
require 'rollbar/exception_reporter'
require 'rollbar/util'
require 'rollbar/railtie' if defined?(Rails::VERSION) && Rails::VERSION::MAJOR >= 3
require 'rollbar/delay/girl_friday' if defined?(GirlFriday)
require 'rollbar/delay/thread'
require 'rollbar/truncation'
require 'rollbar/exceptions'
require 'rollbar/lazy_store'

module Rollbar
  ATTACHMENT_CLASSES = %w[
    ActionDispatch::Http::UploadedFile
    Rack::Multipart::UploadedFile
  ].freeze
  PUBLIC_NOTIFIER_METHODS = %w(debug info warn warning error critical log logger
                               process_payload process_from_async_handler scope send_failsafe log_info log_debug
                               log_warning log_error silenced)

  class Notifier
    attr_accessor :configuration
    attr_accessor :last_report
    attr_reader :scope_object

    @file_semaphore = Mutex.new

    def initialize(parent_notifier = nil, payload_options = nil, scope = nil)
      if parent_notifier
        @configuration = parent_notifier.configuration.clone
        @scope_object = parent_notifier.scope_object.clone

        Rollbar::Util.deep_merge(@configuration.payload_options, payload_options) if payload_options
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
          process_payload(payload)
        rescue => e
          report_internal_error(e)

          raise
        end
      end
    end

    def custom_data
      data = configuration.payload_options[:extra].call
      Rollbar::Util.deep_copy(data)

    rescue => e
      return {} if configuration.safely?

      report_custom_data_error(e)
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
      Rollbar::Util.deep_merge(data, scope_object)

      # Our API doesn't allow null context values, so just delete
      # the key if value is nil.
      data.delete(:context) unless data[:context]
      data.delete(:extra)

      payload = {
        'access_token' => configuration.access_token,
        'data' => data
      }

      enforce_valid_utf8(payload)

      call_transform(:level => level,
                     :exception => exception,
                     :message => message,
                     :extra => extra,
                     :payload => payload)

      payload
    end

    def call_transform(options)
      options = {
        :level => options[:level],
        :scope => scope_object,
        :exception => options[:exception],
        :message => options[:message],
        :extra => options[:extra],
        :payload => options[:payload]
      }
      handlers = configuration.transform

      handlers.each do |handler|
        begin
          handler.call(options)
        rescue => e
          log_error("[Rollbar] Error calling the `transform` hook: #{e}")

          break
        end
      end
    end

    def build_payload_body(message, exception, extra)
      if custom_data_method? && configuration.payload_options[:extra].respond_to?(:call)
        extra = Rollbar::Util.deep_merge(custom_data, extra || {})
      end

      if exception
        build_payload_body_exception(message, exception, extra)
      else
        build_payload_body_message(message, extra)
      end
    end

    def custom_data_method?
      !!(Rollbar.configuration.custom_data_method || Rollbar.configuration.custom_values.count > 0)
    end

    def report_custom_data_error(e)
      data = safely.error(e)

      return {} unless data.is_a?(Hash) && data[:uuid]

      uuid_url = uuid_rollbar_url(data)

      { :_error_in_custom_data_method => uuid_url }
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

      while exception.respond_to?(:cause) && (cause = exception.cause) && cause.is_a?(Exception) && !visited.include?(cause)
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
      normalizer = lambda { |object| Encoding.encode(object) }

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
      payload = Rollbar::JSON.load(payload) if payload.is_a?(String)

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
        # This is needed to have 1.8.7 passing tests
        http.ca_file = ENV['ROLLBAR_SSL_CERT_FILE'] if ENV.has_key?('ROLLBAR_SSL_CERT_FILE')
        http.verify_mode = ssl_verify_mode
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

    def ssl_verify_mode
      if configuration.verify_ssl_peer
        OpenSSL::SSL::VERIFY_PEER
      else
        OpenSSL::SSL::VERIFY_NONE
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
        schedule_payload(failsafe_payload)
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

          log_error "[Rollbar] All failover handlers failed while processing payload: #{Rollbar::JSON.dump(payload)}"
        end
      end
    end

    def dump_payload(payload)
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
        uuid_url = uuid_rollbar_url(data)
        log_info "[Rollbar] Details: #{uuid_url} (only available if report was successful)"
      end
    end

    def uuid_rollbar_url(data)
      "#{configuration.web_base}/instance/uuid?uuid=#{data[:uuid]}"
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

      reset_notifier!
    end

    def configure
      # if configuration.enabled has not been set yet (is still 'nil'), set to true.
      configuration.enabled = true if configuration.enabled.nil?

      yield(configuration)

      prepare
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

    def prepare
      prepare_js
      require_hooks
      require_core_extensions
    end

    def prepare_js
      ::Rollbar::Js.prepare if configuration.js_enabled
    end

    def require_hooks
      return if configuration.disable_monkey_patch
      wrap_delayed_worker

      if defined?(ActiveRecord)
        require 'active_record/version'
        require 'rollbar/active_record_extension' if ActiveRecord::VERSION::MAJOR >= 3
      end

      require 'rollbar/sidekiq' if defined?(Sidekiq)
      require 'rollbar/active_job' if defined?(ActiveJob)
      require 'rollbar/goalie' if defined?(Goalie)
      require 'rollbar/rack' if defined?(Rack) unless configuration.disable_rack_monkey_patch
      require 'rollbar/rake' if defined?(Rake)
    end

    def require_core_extensions
      # This monkey patch is always needed in order
      # to use Rollbar.scoped
      require 'rollbar/core_ext/thread'

      return if configuration.disable_core_monkey_patch

      # Needed to avoid active_support (< 4.1.0) bug serializing JSONs
      require 'rollbar/core_ext/basic_socket' if monkey_patch_socket?
    end

    def monkey_patch_socket?
      defined?(ActiveSupport::VERSION::STRING)
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
