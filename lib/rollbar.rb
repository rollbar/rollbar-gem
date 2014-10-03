require 'net/https'
require 'socket'
require 'thread'
require 'uri'
require 'multi_json'

begin
  require 'securerandom'
rescue LoadError
end

require 'rollbar/version'
require 'rollbar/configuration'
require 'rollbar/request_data_extractor'
require 'rollbar/exception_reporter'
require 'rollbar/active_record_extension' if defined?(ActiveRecord)
require 'rollbar/util'
require 'rollbar/railtie' if defined?(Rails)

unless ''.respond_to? :encode
  require 'iconv'
end

module Rollbar
  MAX_PAYLOAD_SIZE = 128 * 1024 #128kb

  class << self
    attr_writer :configuration
    attr_accessor :last_report

    # Similar to configure below, but used only internally within the gem
    # to configure it without initializing any of the third party hooks
    def preconfigure
      yield(configuration)
    end

    # Configures the gem.
    #
    # Call on app startup to set the `access_token` (required) and other config params.
    # In a Rails app, this is called by `config/initializers/rollbar.rb` which is generated
    # with `rails generate rollbar access-token-here`
    #
    # @example
    #   Rollbar.configure do |config|
    #     config.access_token = 'abcdefg'
    #   end
    def configure
      # if configuration.enabled has not been set yet (is still 'nil'), set to true.
      if configuration.enabled.nil?
        configuration.enabled = true
      end
      yield(configuration)

      if configuration[:locals][:enabled]
        start_tracking_locals
      else
        stop_tracking_locals
      end

      require_hooks
    end

    def reconfigure
      @configuration = Configuration.new
      @configuration.enabled = true
      yield(configuration)
    end

    def unconfigure
      @configuration = nil
    end

    # Returns the configuration object.
    #
    # @return [Rollbar::Configuration] The configuration object
    def configuration
      @configuration ||= Configuration.new
    end

    # Reports an exception to Rollbar. Returns the exception data hash.
    #
    # @example
    #   begin
    #     foo = bar
    #   rescue => e
    #     Rollbar.report_exception(e)
    #   end
    #
    # @param exception [Exception] The exception object to report
    # @param request_data [Hash] Data describing the request. Should be the result of calling
    #   `rollbar_request_data`.
    # @param person_data [Hash] Data describing the affected person. Should be the result of calling
    #   `rollbar_person_data`
    def report_exception(exception, request_data = nil, person_data = nil, level = nil)
      if person_data
        person_id = person_data[Rollbar.configuration.person_id_method.to_sym]
        return 'ignored' if configuration.ignored_person_ids.include?(person_id)
      end

      return 'disabled' unless configuration.enabled
      return 'ignored' if ignored?(exception)

      data = exception_data(exception, level ? level : filtered_level(exception))

      attach_request_data(data, request_data) if request_data
      data[:person] = person_data if person_data

      @last_report = data

      payload = build_payload(data)
      schedule_payload(payload)
      log_instance_link(data)
      data
    rescue Exception => e
      report_internal_error(e)
      'error'
    end

    # Reports an arbitrary message to Rollbar
    #
    # @example
    #   Rollbar.report_message("User login failed", 'info', :user_id => 123)
    #
    # @param message [String] The message body. This will be used to identify the message within
    #   Rollbar. For best results, avoid putting variables in the message body; pass them as
    #   `extra_data` instead.
    # @param level [String] The level. One of: 'critical', 'error', 'warning', 'info', 'debug'
    # @param extra_data [Hash] Additional data to include alongside the body. Don't use 'body' as
    #   it is reserved.
    def report_message(message, level = 'info', extra_data = {})
      return 'disabled' unless configuration.enabled

      data = message_data(message, level, extra_data)

      @last_report = data

      payload = build_payload(data)
      schedule_payload(payload)
      log_instance_link(data)
      data
    rescue Exception => e
      report_internal_error(e)
      'error'
    end

    # Reports an arbitrary message to Rollbar with request and person data
    #
    # @example
    #   Rollbar.report_message_with_request("User login failed", 'info', rollbar_request_data, rollbar_person_data, :foo => 'bar')
    #
    # @param message [String] The message body. This will be used to identify the message within
    #   Rollbar. For best results, avoid putting variables in the message body; pass them as
    #   `extra_data` instead.
    # @param level [String] The level. One of: 'critical', 'error', 'warning', 'info', 'debug'
    # @param request_data [Hash] Data describing the request. Should be the result of calling
    #   `rollbar_request_data`.
    # @param person_data [Hash] Data describing the affected person. Should be the result of calling
    #   `rollbar_person_data`
    # @param extra_data [Hash] Additional data to include alongside the body. Don't use 'body' as
    #   it is reserved.
    def report_message_with_request(message, level = 'info', request_data = nil, person_data = nil, extra_data = {})
      return 'disabled' unless configuration.enabled

      data = message_data(message, level, extra_data)

      attach_request_data(data, request_data) if request_data
      data[:person] = person_data if person_data

      @last_report = data

      payload = build_payload(data)
      schedule_payload(payload)
      log_instance_link(data)
      data
    rescue => e
      report_internal_error(e)
      'error'
    end

    # Turns off reporting for the given block.
    #
    # @example
    #   Rollbar.silenced { raise }
    #
    # @yield Block which exceptions won't be reported.
    def silenced
      begin
        yield
      rescue => e
        e.instance_variable_set(:@_rollbar_do_not_report, true)
        raise
      end
    end

    def process_payload(payload)
      begin
        if configuration.write_to_file
          write_payload(payload)
        else
          send_payload(payload)
        end
      rescue => e
        log_error "[Rollbar] Error processing payload: #{e}"
      end
    end

    # wrappers around logger methods
    def log_error(message)
      begin
        logger.error message
      rescue => e
        puts "[Rollbar] Error logging error:"
        puts "[Rollbar] #{message}"
      end
    end

    def log_info(message)
      begin
        logger.info message
      rescue => e
        puts "[Rollbar] Error logging info:"
        puts "[Rollbar] #{message}"
      end
    end

    def log_warning(message)
      begin
        logger.warn message
      rescue => e
        puts "[Rollbar] Error logging warning:"
        puts "[Rollbar] #{message}"
      end
    end
    def log_debug(message)
      begin
        logger.debug message
      rescue => e
        puts "[Rollbar] Error logging debug"
        puts "[Rollbar] #{message}"
      end
    end

    private

    # Trace local variables and method args per stack frame
    # Save an on-going stack of local variable contexts
    # To "replay" the stack, traverse the @trace_store from back to front (top to bottom)
    attr_accessor :trace_store
    attr_accessor :trace_store_search_index # used to iterate through trace_store
    attr_accessor :is_tracing
    attr_accessor :seen_first_return

    def trace_store
      @trace_store ||= []
    end

    def add_trace_frame_locals(filename, lineno, local_variables={})
      trace_store << { :filename => filename, :lineno => lineno }.merge!(local_variables)
      # keep store within limits
      trace_store.shift if trace_store.count > configuration[:locals][:max_trace_frames]
    end

    # Returns the most recently stored local variables for a given filename and line number
    # Uses @trace_store_search_index to know where to we left off
    def recent_trace_frame_locals(filename, lineno)
      @trace_store_search_index ||= -1
      while (@trace_store_search_index += 1) < trace_store.count
        current_frame = trace_store[@trace_store_search_index]
        if current_frame[:filename] == filename && current_frame[:lineno] == lineno
          return current_frame
        end
      end
      # or fallback
      local_variables_struct
    end

    def reset_current_trace
      @trace_store_search_index = nil
      trace_store = nil
    end

    # Use this eval string to get arguments of __method__
    # Omit `:block` arguments because they may require unpredicable parameters
    EVAL_GET_METHOD_ARGUMENT_NAMES = %{
      if __method__ && respond_to?(__method__)
         method(__method__).parameters.map{ |p_type, p_name| p_name unless p_type == :block }.collect
      end
    }

    # Method#parameters is unavailable in Ruby 1.8.7 and below
    CAN_CHECK_METHOD_PARAMS = Method.method_defined? :parameters

    def local_variables_struct
      if CAN_CHECK_METHOD_PARAMS
        { :locals => {}, :args => {} }
      else
        { :locals => {} }
      end
    end

    def start_tracking_locals
      reset_current_trace
      set_trace_func proc { |event, file, line, id, binding, classname|
        if @is_tracing
          if event == "return" or @seen_first_return
            @seen_first_return = true if event == "return"
            # get local and arg variables
            local_vars = local_variables_struct
            begin
              all_variable_names = binding.eval("local_variables")
              arg_names = CAN_CHECK_METHOD_PARAMS ? binding.eval(EVAL_GET_METHOD_ARGUMENT_NAMES) : []
            rescue => e
              log_error "[Rollbar] Error getting names of local variables: #{e}"
            end
            all_variable_names ||= []
            arg_names ||= []

            all_variable_names.each do |var_name|
              begin
                if var_value = binding.eval(var_name.to_s)
                  var_name = var_name.to_sym # ensure symbol for older versions of Ruby
                  if arg_names.include? var_name
                    local_vars[:args][var_name] = var_value
                  else
                    local_vars[:locals][var_name] = var_value
                  end
                end
              rescue => e
                log_error "[Rollbar] Error accessing local variables: #{e}"
              end
            end

            # if we've already seen the first "return" and this is not a return
            # this will be the last frame we trace
            if @seen_first_return and event != "return"
              @is_tracing = false
              # In order to match the backtrace frames, subtract the last frame's lineno by 1
              add_trace_frame_locals(file, line-1, local_vars)
            else
              add_trace_frame_locals(file, line, local_vars)
            end
          end
        else
          # Start tracing once we see the first return
          if id == :backtrace and classname == Exception and event == "c-return"
            reset_current_trace
            @is_tracing = true
            @seen_first_return = false
          end
        end
      }
    end

    def stop_tracking_locals
      reset_current_trace
      set_trace_func(nil)
    end

    def attach_request_data(payload, request_data)
      if request_data[:route]
        route = request_data[:route]

        # make sure route is a hash built by RequestDataExtractor in rails apps
        if route.is_a?(Hash) and not route.empty?
          payload[:context] = "#{request_data[:route][:controller]}" + '#' + "#{request_data[:route][:action]}"
        end
      end

      request_data[:env].reject!{|k, v| v.is_a?(IO) } if request_data[:env]
      payload[:request] = request_data
    end

    def require_hooks()
      if defined?(Delayed) && defined?(Delayed::Worker) && configuration.delayed_job_enabled
        require 'rollbar/delayed_job'
        Rollbar::Delayed::wrap_worker
      end

      require 'rollbar/sidekiq' if defined?(Sidekiq)
      require 'rollbar/goalie' if defined?(Goalie)
      require 'rollbar/rack' if defined?(Rack)
      require 'rollbar/rake' if defined?(Rake)
      require 'rollbar/better_errors' if defined?(BetterErrors)
    end

    def log_instance_link(data)
      log_info "[Rollbar] Details: #{configuration.web_base}/instance/uuid?uuid=#{data[:uuid]} (only available if report was successful)"
    end

    def ignored?(exception)
      if filtered_level(exception) == 'ignore'
        return true
      end

      if exception.instance_variable_get(:@_rollbar_do_not_report)
        return true
      end

      false
    end

    def filtered_level(exception)
      filter = configuration.exception_level_filters[exception.class.name]
      if filter.respond_to?(:call)
        filter.call(exception)
      else
        filter
      end
    end

    def message_data(message, level, extra_data)
      data = base_data(level)

      data[:body] = {
        :message => {
          :body => message.to_s
        }
      }
      data[:body][:message].merge!(extra_data)
      data[:server] = server_data

      data
    end

    def exception_data(exception, force_level = nil)
      data = base_data

      data[:level] = force_level if force_level

      # parse backtrace
      if exception.backtrace.respond_to?( :map )
        frames = exception.backtrace.map { |frame|
          # parse the line
          match = frame.match(/(.*):(\d+)(?::in `([^']+)')?/)
          if match
            frame_info = { :filename => match[1], :lineno => match[2].to_i, :method => match[3] }
          else
            frame_info = { :filename => "<unknown>", :lineno => 0, :method => frame }
          end

          # add frame locals
          if configuration[:locals][:enabled]
            locals = recent_trace_frame_locals(frame_info[:filename], frame_info[:lineno])
            frame_info.merge!(locals)
          end

          frame_info
        }
        # reverse so that the order is as rollbar expects
        frames.reverse!
      else
        frames = []
      end

      data[:body] = {
        :trace => {
          :frames => frames,
          :exception => {
            :class => exception.class.name,
            :message => exception.message
          }
        }
      }

      data[:server] = server_data

      reset_current_trace
      data
    end

    def logger
      # init if not set
      unless configuration.logger
        configuration.logger = configuration.default_logger.call
      end
      configuration.logger
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

      begin
        unless @file
          @file = File.open(configuration.filepath, "a")
        end

        @file.puts payload
        @file.flush
        log_info "[Rollbar] Success"
      rescue IOError => e
        log_error "[Rollbar] Error opening/writing to file: #{e}"
      end
    end

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

    def schedule_payload(payload)
      if payload.nil?
        return
      end

      log_info '[Rollbar] Scheduling payload'

      if configuration.use_async
        unless configuration.async_handler
          configuration.async_handler = method(:default_async_handler)
        end

        if configuration.write_to_file
          unless @file_semaphore
            @file_semaphore = Mutex.new
          end
        end

        configuration.async_handler.call(payload)
      else
        process_payload(payload)
      end
    end

    def build_payload(data)
      payload = {
        'access_token' => configuration.access_token,
        'data' => data
      }

      enforce_valid_utf8(payload)
      payload
    end

    def dump_payload(payload)
      result = MultiJson.dump(payload)

      # Try to truncate strings in the payload a few times if the payload is too big
      original_size = result.bytesize
      if original_size > MAX_PAYLOAD_SIZE
        thresholds = [1024, 512, 256]
        thresholds.each_with_index do |threshold, i|
          new_payload = payload.clone

          truncate_payload(new_payload, threshold)

          result = MultiJson.dump(new_payload)

          if result.bytesize <= MAX_PAYLOAD_SIZE
            break
          elsif i == thresholds.length - 1
            final_size = result.bytesize
            send_failsafe("Could not send payload due to it being too large after truncating attempts. Original size: #{original_size} Final size: #{final_size}", nil)
            log_error "[Rollbar] Payload too large to be sent: #{MultiJson.dump(payload)}"
            return
          end
        end
      end

      result
    end

    def base_data(level = 'error')
      config = configuration

      environment = config.environment
      if environment.nil? || environment.empty?
        environment = 'unspecified'
      end

      data = {
        :timestamp => Time.now.to_i,
        :environment => environment,
        :level => level,
        :language => 'ruby',
        :framework => config.framework,
        :project_package_paths => config.project_gem_paths,
        :notifier => {
          :name => 'rollbar-gem',
          :version => VERSION
        }
      }

      if config.code_version
        data[:code_version] = config.code_version
      end

      if defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)
        data[:uuid] = SecureRandom.uuid
      end

      unless config.custom_data_method.nil?
        data[:custom] = config.custom_data_method.call
      end

      data
    end

    def server_data
      config = configuration

      data = {
        :host => Socket.gethostname
      }
      data[:root] = config.root.to_s if config.root
      data[:branch] = config.branch if config.branch

      data
    end

    def default_async_handler(payload)
      if defined?(GirlFriday)
        unless @queue
          @queue = GirlFriday::WorkQueue.new(nil, :size => 5) do |payload|
            process_payload(payload)
          end
        end

        @queue.push(payload)
      else
        log_warning '[Rollbar] girl_friday not found to handle async call, falling back to Thread'
        Thread.new { process_payload(payload) }
      end
    end

    # Reports an internal error in the Rollbar library. This will be reported within the configured
    # Rollbar project. We'll first attempt to provide a report including the exception traceback.
    # If that fails, we'll fall back to a more static failsafe response.
    def report_internal_error(exception)
      log_error "[Rollbar] Reporting internal error encountered while sending data to Rollbar."

      begin
        data = exception_data(exception, 'error')
      rescue => e
        send_failsafe("error in exception_data", e)
        return
      end

      data[:internal] = true

      begin
        payload = build_payload(data)
      rescue => e
        send_failsafe("error in build_payload", e)
        return
      end

      begin
        schedule_payload(payload)
      rescue => e
        send_failsafe("error in schedule_payload", e)
        return
      end

      begin
        log_instance_link(data)
      rescue => e
        send_failsafe("error logging instance link", e)
        return
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
        :environment => "#{environment}",
        :body => { :message => { :body => "Failsafe from rollbar-gem: #{message}" } },
        :notifier => { :name => 'rollbar-gem', :version => "#{VERSION}" },
        :internal => true,
        :failsafe => true
      }

      failsafe_payload = build_payload(failsafe_data)

      begin
        schedule_payload(failsafe_payload)
      rescue => e
        log_error "[Rollbar] Error sending failsafe : #{e}"
      end
    end

    def enforce_valid_utf8(payload)
      normalizer = Proc.new do |value|
        if value.is_a?(String)
          if value.respond_to? :encode
            value.encode('UTF-8', 'binary', :invalid => :replace, :undef => :replace, :replace => '')
          else
            ::Iconv.conv('UTF-8//IGNORE', 'UTF-8', value)
          end
        else
          value
        end
      end

      Rollbar::Util::iterate_and_update(payload, normalizer)
    end

    def truncate_payload(payload, byte_threshold)
      truncator = Proc.new do |value|
        if value.is_a?(String) and value.bytesize > byte_threshold
          Rollbar::Util::truncate(value, byte_threshold)
        else
          value
        end
      end

      Rollbar::Util::iterate_and_update(payload, truncator)
    end
  end
end

# Setting Ratchetio as an alias to Rollbar for ratchetio-gem backwards compatibility
Ratchetio = Rollbar
