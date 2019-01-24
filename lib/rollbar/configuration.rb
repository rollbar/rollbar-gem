require 'logger'

module Rollbar
  class Configuration
    SEND_EXTRA_FRAME_DATA_OPTIONS = [:none, :app, :all].freeze

    attr_accessor :access_token
    attr_accessor :async_handler
    attr_accessor :branch
    attr_reader :before_process
    attr_accessor :code_version
    attr_accessor :custom_data_method
    attr_accessor :delayed_job_enabled
    attr_accessor :default_logger
    attr_reader :logger_level
    attr_accessor :disable_monkey_patch
    attr_accessor :disable_rack_monkey_patch
    attr_accessor :disable_core_monkey_patch
    attr_accessor :dj_threshold
    attr_accessor :enabled
    attr_accessor :endpoint
    attr_accessor :environment
    attr_accessor :exception_level_filters
    attr_accessor :failover_handlers
    attr_accessor :filepath
    attr_accessor :framework
    attr_accessor :ignored_person_ids
    attr_accessor :host
    attr_writer :logger
    attr_accessor :payload_options
    attr_accessor :person_method
    attr_accessor :person_id_method
    attr_accessor :person_username_method
    attr_accessor :person_email_method
    attr_accessor :populate_empty_backtraces
    attr_accessor :report_dj_data
    attr_accessor :open_timeout
    attr_accessor :request_timeout
    attr_accessor :net_retries
    attr_accessor :root
    attr_accessor :js_options
    attr_accessor :js_enabled
    attr_accessor :safely
    attr_accessor :scrub_fields
    attr_accessor :scrub_user
    attr_accessor :scrub_password
    attr_accessor :scrub_whitelist
    attr_accessor :collect_user_ip
    attr_accessor :anonymize_user_ip
    attr_accessor :user_ip_obfuscator_secret
    attr_accessor :randomize_scrub_length
    attr_accessor :uncaught_exception_level
    attr_accessor :scrub_headers
    attr_accessor :sidekiq_threshold
    attr_reader :transform
    attr_accessor :verify_ssl_peer
    attr_accessor :use_async
    attr_reader :use_eventmachine
    attr_accessor :web_base
    attr_accessor :write_to_file
    attr_reader :send_extra_frame_data
    attr_accessor :use_exception_level_filters_default
    attr_accessor :proxy

    attr_reader :project_gem_paths

    alias_method :safely?, :safely

    DEFAULT_ENDPOINT = 'https://api.rollbar.com/api/1/item/'
    DEFAULT_WEB_BASE = 'https://rollbar.com'

    def initialize
      @async_handler = nil
      @before_process = []
      @code_version = nil
      @custom_data_method = nil
      @default_logger = lambda { ::Logger.new(STDERR) }
      @logger_level = :info
      @delayed_job_enabled = true
      @disable_monkey_patch = false
      @disable_core_monkey_patch = false
      @disable_rack_monkey_patch = false
      @dj_threshold = 0
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
      @ignored_person_ids = []
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
      @js_enabled = false
      @js_options = {}
      @scrub_fields = [:passwd, :password, :password_confirmation, :secret,
                       :confirm_password, :password_confirmation, :secret_token,
                       :api_key, :access_token, :session_id]
      @scrub_user = true
      @scrub_password = true
      @randomize_scrub_length = true
      @scrub_whitelist = []
      @uncaught_exception_level = 'error'
      @scrub_headers = ['Authorization']
      @sidekiq_threshold = 0
      @safely = false
      @transform = []
      @use_async = false
      @use_eventmachine = false
      @verify_ssl_peer = true
      @web_base = DEFAULT_WEB_BASE
      @write_to_file = false
      @send_extra_frame_data = :none
      @project_gem_paths = []
      @use_exception_level_filters_default = false
      @proxy = nil
      @collect_user_ip = true
      @anonymize_user_ip = false
      @hooks = {
        :on_error_response => nil, # params: response
        :on_report_internal_error => nil, #params: exception
      }
    end

    def initialize_copy(orig)
      super

      instance_variables.each do |var|
        instance_var = instance_variable_get(var)
        instance_variable_set(var, Rollbar::Util::deep_copy(instance_var))
      end
    end

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

      Rollbar::Delay::ActiveJob.queue_as(options[:queue] || Rollbar::Delay::ActiveJob.default_queue_name)
      
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
      deprecation_message = '#use_sidekiq=(value) has been deprecated in favor of #use_sidekiq(options = {}). Please update your rollbar configuration.'
      defined?(ActiveSupport) ? ActiveSupport::Deprecation.warn(deprecation_message) : puts(deprecation_message)

      value.is_a?(Hash) ? use_sidekiq(value) : use_sidekiq
    end

    def use_thread
      require 'rollbar/delay/thread'
      @use_async = true
      @async_handler = Rollbar::Delay::Thread
    end

    def use_sucker_punch
      require 'rollbar/delay/sucker_punch' if defined?(SuckerPunch)
      @use_async      = true
      @async_handler  = Rollbar::Delay::SuckerPunch
    end

    def use_sucker_punch=(value)
      deprecation_message = '#use_sucker_punch=(value) has been deprecated in favor of #use_sucker_punch. Please update your rollbar configuration.'
      defined?(ActiveSupport) ? ActiveSupport::Deprecation.warn(deprecation_message) : puts(deprecation_message)

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
      end.flatten.uniq.map(&:gem_dir)
    end

    def before_process=(*handler)
      @before_process = Array(handler)
    end

    def transform=(*handler)
      @transform = Array(handler)
    end

    def send_extra_frame_data=(value)
      unless SEND_EXTRA_FRAME_DATA_OPTIONS.include?(value)
        logger.warning("Wrong 'send_extra_frame_data' value, :none, :app or :full is expected")

        return
      end

      @send_extra_frame_data = value
    end

    # allow params to be read like a hash
    def [](option)
      send(option)
    end

    def logger_level=(level)
      @logger_level = level.to_sym
    end

    def logger
      @logger ||= default_logger.call
    end
    
    def hook(symbol, &block)
      if @hooks.has_key?(symbol)
        if block_given?
          @hooks[symbol] = block
        else
          @hooks[symbol]
        end
      else
        raise StandardError.new "Hook :" + symbol.to_s + " is not supported by Rollbar SDK."
      end
    end
    
    def execute_hook(symbol, *args)
      hook(symbol).call(*args) if hook(symbol).is_a?(Proc)
    end
  end
end
