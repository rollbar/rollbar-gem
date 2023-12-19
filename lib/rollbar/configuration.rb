require 'logger'

module Rollbar
  class Configuration
    SEND_EXTRA_FRAME_DATA_OPTIONS = [:none, :app, :all].freeze

    attr_accessor :access_token,
                  :anonymize_user_ip,
                  :async_handler,
                  :async_json_payload,
                  :async_skip_report_handler,
                  :backtrace_cleaner,
                  :branch,
                  :capture_uncaught,
                  :code_version,
                  :collect_user_ip,
                  :configured_options,
                  :custom_data_method,
                  :default_logger,
                  :delayed_job_enabled,
                  :disable_core_monkey_patch,
                  :disable_monkey_patch,
                  :disable_rack_monkey_patch,
                  :dj_threshold,
                  :dj_use_scoped_block,
                  :enable_error_context,
                  :enabled,
                  :endpoint,
                  :environment,
                  :exception_level_filters,
                  :failover_handlers,
                  :filepath,
                  :files_processed_duration,
                  :files_processed_enabled,
                  :files_processed_size,
                  :files_with_pid_name_enabled,
                  :framework,
                  :ignore_internal_errors,
                  :ignored_person_ids,
                  :js_enabled,
                  :js_options,
                  :host,
                  :locals,
                  :log_payload,
                  :net_retries,
                  :open_timeout,
                  :payload_options,
                  :person_email_method,
                  :person_id_method,
                  :person_method,
                  :person_username_method,
                  :populate_empty_backtraces,
                  :proxy,
                  :raise_on_error,
                  :randomize_scrub_length,
                  :report_dj_data,
                  :request_timeout,
                  :root,
                  :safely,
                  :scrub_fields,
                  :scrub_password,
                  :scrub_user,
                  :scrub_whitelist,
                  :transmit,
                  :uncaught_exception_level,
                  :user_ip_obfuscator_secret,
                  :user_ip_rack_env_key,
                  :scrub_headers,
                  :sidekiq_threshold,
                  :sidekiq_use_scoped_block,
                  :use_async,
                  :use_exception_level_filters_default,
                  :use_payload_access_token,
                  :verify_ssl_peer,
                  :web_base,
                  :write_to_file
    attr_reader :before_process,
                :logger_level,
                :project_gem_paths,
                :send_extra_frame_data,
                :transform,
                :use_eventmachine
    attr_writer :logger # seconds # bytes

    alias safely? safely

    DEFAULT_ENDPOINT = 'https://api.rollbar.com/api/1/item/'.freeze
    DEFAULT_WEB_BASE = 'https://rollbar.com'.freeze

    def initialize
      @access_token = nil
      @async_handler = nil
      @before_process = []
      @branch = nil
      @capture_uncaught = nil
      @code_version = nil
      @custom_data_method = nil
      @default_logger = lambda { ::Logger.new($stderr) }
      @logger_level = :info
      @delayed_job_enabled = true
      @disable_monkey_patch = false
      @disable_core_monkey_patch = false
      @disable_rack_monkey_patch = false
      @enable_error_context = true
      @dj_threshold = 0
      @dj_use_scoped_block = false
      @async_skip_report_handler = nil
      @enabled = nil # set to true when configure is called
      @endpoint = DEFAULT_ENDPOINT
      @environment = nil
      @exception_level_filters = {
        'ActiveRecord::RecordNotFound' => 'warning',
        'AbstractController::ActionNotFound' => 'warning',
        'ActionController::RoutingError' => 'warning'
      }
      @failover_handlers = []
      @framework = 'Plain'
      @ignore_internal_errors = [
        'Net::ReadTimeout',
        'Net::OpenTimeout',
        'SocketError'
      ]
      @ignored_person_ids = []
      @host = nil
      @payload_options = {}
      @person_method = 'current_user'
      @person_id_method = 'id'
      @person_username_method = nil
      @person_email_method = nil
      @project_gems = []
      @populate_empty_backtraces = false
      @report_dj_data = true
      @open_timeout = 3
      @request_timeout = 3
      @net_retries = 3
      @root = nil
      @js_enabled = false
      @js_options = {}
      @locals = {}
      @scrub_fields = [:passwd, :password, :password_confirmation, :secret,
                       :confirm_password, :password_confirmation, :secret_token,
                       :api_key, :access_token, :accessToken, :session_id]
      @scrub_user = true
      @scrub_password = true
      @randomize_scrub_length = false
      @scrub_whitelist = []
      @uncaught_exception_level = 'error'
      @scrub_headers = ['Authorization']
      @sidekiq_threshold = 0
      @sidekiq_use_scoped_block = false
      @safely = false
      @transform = []
      @use_async = false
      @async_json_payload = false
      @use_eventmachine = false
      @verify_ssl_peer = true
      @web_base = DEFAULT_WEB_BASE
      @send_extra_frame_data = :none
      @project_gem_paths = []
      @use_exception_level_filters_default = false
      @proxy = nil
      @raise_on_error = false
      @transmit = true
      @log_payload = false
      @collect_user_ip = true
      @anonymize_user_ip = false
      @user_ip_obfuscator_secret = nil
      @user_ip_rack_env_key = nil
      @backtrace_cleaner = nil
      @hooks = {
        :on_error_response => nil, # params: response
        :on_report_internal_error => nil # params: exception
      }

      @write_to_file = false
      @filepath = nil
      @files_with_pid_name_enabled = false
      @files_processed_enabled = false
      @files_processed_duration = 60
      @files_processed_size = 5 * 1000 * 1000
      @use_payload_access_token = false

      @configured_options = ConfiguredOptions.new(self)
    end

    def initialize_copy(orig)
      super

      instance_variables.each do |var|
        instance_var = instance_variable_get(var)
        instance_variable_set(var, Rollbar::Util.deep_copy(instance_var))
      end
    end

    def wrapped_clone
      original_clone.tap do |new_config|
        new_config.configured_options = ConfiguredOptions.new(new_config)
        new_config.configured_options.configured = configured_options.configured
      end
    end
    alias original_clone clone
    alias clone wrapped_clone

    def merge(options)
      new_configuration = clone
      new_configuration.merge!(options)

      new_configuration
    end

    def merge!(options)
      options.each do |name, value|
        variable_name = "@#{name}"
        next unless instance_variable_defined?(variable_name)

        instance_variable_set(variable_name, value)
      end

      self
    end

    def use_active_job(options = {})
      require 'rollbar/delay/active_job'

      Rollbar::Delay::ActiveJob.queue_as(options[:queue] ||
      Rollbar::Delay::ActiveJob.default_queue_name)

      @use_async      = true
      @async_handler  = Rollbar::Delay::ActiveJob
    end

    def use_delayed_job(options = {})
      require 'rollbar/delay/delayed_job'

      Rollbar::Delay::DelayedJob.queue = options[:queue] if options[:queue]

      @use_async      = true
      @async_handler  = Rollbar::Delay::DelayedJob
    end

    def use_sidekiq(options = {})
      require 'rollbar/delay/sidekiq' if defined?(Sidekiq)
      @use_async      = true
      @async_handler  = Rollbar::Delay::Sidekiq.new(options)
    end

    def use_resque(options = {})
      require 'rollbar/delay/resque' if defined?(Resque)

      Rollbar::Delay::Resque::Job.queue = options[:queue] if options[:queue]

      @use_async      = true
      @async_handler  = Rollbar::Delay::Resque
    end

    def use_shoryuken(options = {})
      require 'rollbar/delay/shoryuken' if defined?(Shoryuken)

      Rollbar::Delay::Shoryuken.queue = options[:queue] if options[:queue]

      @use_async      = true
      @async_handler  = Rollbar::Delay::Shoryuken
    end

    def use_sidekiq=(value)
      deprecation_message = '#use_sidekiq=(value) has been deprecated in favor ' \
        'of #use_sidekiq(options = {}). Please update your rollbar configuration.'
      if defined?(ActiveSupport)
        ActiveSupport::Deprecation.warn(deprecation_message)
      else
        puts(deprecation_message)
      end

      value.is_a?(Hash) ? use_sidekiq(value) : use_sidekiq
    end

    def use_thread(options = {})
      require 'rollbar/delay/thread'
      @use_async = true
      Rollbar::Delay::Thread.options = options
      @async_handler = Rollbar::Delay::Thread
    end

    def use_sucker_punch
      require 'rollbar/delay/sucker_punch' if defined?(SuckerPunch)
      @use_async      = true
      @async_handler  = Rollbar::Delay::SuckerPunch
    end

    def use_sucker_punch=(_value)
      deprecation_message = '#use_sucker_punch=(value) has been deprecated in ' \
        'favor of #use_sucker_punch. Please update your rollbar configuration.'
      if defined?(ActiveSupport)
        ActiveSupport::Deprecation.warn(deprecation_message)
      else
        puts(deprecation_message)
      end

      use_sucker_punch
    end

    def use_eventmachine=(value)
      require 'em-http-request' if value
      @use_eventmachine = value
    end

    def project_gems=(gems)
      @project_gem_paths = gems.map do |name|
        found = Gem::Specification.each.select { |spec| name === spec.name }
        puts "[Rollbar] No gems found matching #{name.inspect}" if found.empty?
        found
      end
      @project_gem_paths.flatten!
      @project_gem_paths.uniq!
      @project_gem_paths.map!(&:gem_dir)
    end

    def before_process=(*handler)
      @before_process = Array(handler)
    end

    def transform=(*handler)
      @transform = Array(handler)
    end

    def send_extra_frame_data=(value)
      unless SEND_EXTRA_FRAME_DATA_OPTIONS.include?(value)
        logger.warning(
          "Wrong 'send_extra_frame_data' value, :none, :app or :all is expected"
        )

        return
      end

      @send_extra_frame_data = value
    end

    # allow params to be read like a hash
    def [](option)
      send(option)
    end

    def logger_level=(level)
      @logger_level = if level
                        level.to_sym
                      else
                        level
                      end
    end

    def logger
      @logger ||= default_logger.call
    end

    def hook(symbol, &block)
      unless @hooks.key?(symbol)
        raise StandardError, "Hook :#{symbol} is not supported by Rollbar SDK."
      end

      if block_given?
        @hooks[symbol] = block
      else
        @hooks[symbol]
      end
    end

    def execute_hook(symbol, *args)
      hook(symbol).call(*args) if hook(symbol).is_a?(Proc)
    end
  end

  class ConfiguredOptions
    attr_accessor :configuration, :configured

    def initialize(configuration)
      @configuration = configuration
      @configured = {}
    end

    def method_missing(method, *args, &block)
      return super unless configuration.respond_to?(method)

      method_string = method.to_s
      if method_string.end_with?('=')
        configured[method_string.chomp('=').to_sym] =
          args.first
      end

      configuration.send(method, *args, &block)
    end

    def respond_to_missing?(method)
      configuration.respond_to?(method) || super
    end
  end
end
