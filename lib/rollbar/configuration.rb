require 'logger'

module Rollbar
  class Configuration

    attr_accessor :access_token
    attr_accessor :async_handler
    attr_accessor :branch
    attr_accessor :code_version
    attr_accessor :custom_data_method
    attr_accessor :delayed_job_enabled
    attr_accessor :default_logger
    attr_accessor :disable_monkey_patch
    attr_accessor :dj_threshold
    attr_accessor :enabled
    attr_accessor :endpoint
    attr_accessor :environment
    attr_accessor :exception_level_filters
    attr_accessor :failover_handlers
    attr_accessor :filepath
    attr_accessor :framework
    attr_accessor :ignored_person_ids
    attr_accessor :logger
    attr_accessor :payload_options
    attr_accessor :person_method
    attr_accessor :person_id_method
    attr_accessor :person_username_method
    attr_accessor :person_email_method
    attr_accessor :populate_empty_backtraces
    attr_accessor :report_dj_data
    attr_accessor :request_timeout
    attr_accessor :root
    attr_accessor :scrub_fields
    attr_accessor :uncaught_exception_level
    attr_accessor :scrub_headers
    attr_accessor :use_async
    attr_accessor :use_eventmachine
    attr_accessor :web_base
    attr_accessor :write_to_file

    attr_reader :project_gem_paths

    DEFAULT_ENDPOINT = 'https://api.rollbar.com/api/1/item/'
    DEFAULT_WEB_BASE = 'https://rollbar.com'

    def initialize
      @async_handler = nil
      @code_version = nil
      @custom_data_method = nil
      @default_logger = lambda { Logger.new(STDERR) }
      @delayed_job_enabled = true
      @disable_monkey_patch = false
      @dj_threshold = 0
      @enabled = nil  # set to true when configure is called
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
      @person_username_method = 'username'
      @person_email_method = 'email'
      @project_gems = []
      @populate_empty_backtraces = false
      @report_dj_data = true
      @request_timeout = 3
      @scrub_fields = [:passwd, :password, :password_confirmation, :secret,
                       :confirm_password, :password_confirmation, :secret_token]
      @uncaught_exception_level = 'error'
      @scrub_headers = ['Authorization']
      @use_async = false
      @use_eventmachine = false
      @web_base = DEFAULT_WEB_BASE
      @write_to_file = false
    end

    def initialize_copy(orig)
      super

      instance_variables.each do |var|
        instance_var = instance_variable_get(var)
        instance_variable_set(var, Rollbar::Util::deep_copy(instance_var))
      end
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

    def use_sidekiq=(value)
      deprecation_message = "#use_sidekiq=(value) has been deprecated in favor of #use_sidekiq(options = {}). Please update your rollbar configuration."
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
      deprecation_message = "#use_sucker_punch=(value) has been deprecated in favor of #use_sucker_punch. Please update your rollbar configuration."
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
        if found.empty?
          puts "[Rollbar] No gems found matching #{name.inspect}"
        end
        found
      end.flatten.uniq.map(&:gem_dir)
    end

    # allow params to be read like a hash
    def [](option)
      send(option)
    end

    def logger
      @logger ||= default_logger.call
    end
  end
end
