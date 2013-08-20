require 'logger'

module Rollbar
  class Configuration

    attr_accessor :access_token
    attr_accessor :async_handler
    attr_accessor :branch
    attr_accessor :custom_data_method
    attr_accessor :default_logger
    attr_accessor :enabled
    attr_accessor :endpoint
    attr_accessor :environment
    attr_accessor :exception_level_filters
    attr_accessor :filepath
    attr_accessor :framework
    attr_accessor :logger
    attr_accessor :person_method
    attr_accessor :person_id_method
    attr_accessor :person_username_method
    attr_accessor :person_email_method
    attr_accessor :root
    attr_accessor :scrub_fields
    attr_accessor :use_sidekiq
    attr_accessor :use_sucker_punch
    attr_accessor :use_async
    attr_accessor :use_eventmachine
    attr_accessor :web_base
    attr_accessor :write_to_file

    attr_reader :project_gem_paths

    DEFAULT_ENDPOINT = 'https://api.rollbar.com/api/1/item/'
    DEFAULT_WEB_BASE = 'https://rollbar.com'

    def initialize
      @async_handler = nil
      @custom_data_method = nil
      @default_logger = lambda { Logger.new(STDERR) }
      @enabled = nil  # set to true when configure is called
      @endpoint = DEFAULT_ENDPOINT
      @environment = 'production'
      @exception_level_filters = {
        'ActiveRecord::RecordNotFound' => 'warning',
        'AbstractController::ActionNotFound' => 'warning',
        'ActionController::RoutingError' => 'warning'
      }
      @framework = 'Plain'
      @person_method = 'current_user'
      @person_id_method = 'id'
      @person_username_method = 'username'
      @person_email_method = 'email'
      @project_gems = []
      @scrub_fields = [:passwd, :password, :password_confirmation, :secret,
                       :confirm_password, :password_confirmation, :secret_token]
      @use_async = false
      @use_sidekiq = false
      @use_sucker_punch = false
      @use_eventmachine = false
      @web_base = DEFAULT_WEB_BASE
      @write_to_file = false
    end

    def use_sidekiq=(value)
      if value
        require 'rollbar/delay/sidekiq' if defined?(Sidekiq)
        @use_async      = true
        @use_sidekiq    = value
        @async_handler  = Rollbar::Delay::Sidekiq.method(:handle)
      end
    end

    def use_sucker_punch=(value)
      if value
        require 'rollbar/delay/sucker_punch' if defined?(SuckerPunch)
        @use_async      = true
        @async_handler  = Rollbar::Delay::SuckerPunch.method(:handle)
      end
    end

    def use_eventmachine=(value)
      require 'em-http-request' if value
      @use_eventmachine = value
    end

    def project_gems=(gems)
      @project_gem_paths = []

      gems.each { |name|
        begin
          spec = Gem::Specification.find_by_name(name.to_s)
          gem_root = spec.gem_dir

          @project_gem_paths.push gem_root
        rescue Gem::LoadError
          puts "[Rollbar] #{name} gem not found"
        end
      }
    end

    # allow params to be read like a hash
    def [](option)
      send(option)
    end
  end
end
