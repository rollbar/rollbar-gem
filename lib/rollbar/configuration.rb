require 'logger'

module Rollbar
  class Configuration

    attr_accessor :access_token
    attr_accessor :async_handler
    attr_accessor :branch
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
    attr_accessor :use_async
    attr_accessor :use_eventmachine
    attr_accessor :web_base
    attr_accessor :write_to_file

    DEFAULT_ENDPOINT = 'https://api.rollbar.com/api/1/item/'
    DEFAULT_WEB_BASE = 'https://rollbar.com'

    def initialize
      @async_handler = nil
      @default_logger = lambda { Logger.new(STDERR) }
      @enabled = false  # set to true when configure is called
      @endpoint = DEFAULT_ENDPOINT
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
      @scrub_fields = [:passwd, :password, :password_confirmation, :secret,
                       :confirm_password, :password_confirmation]
      @use_async = false
      @web_base = DEFAULT_WEB_BASE
      @write_to_file = false
      @use_eventmachine = false
    end
    
    def use_eventmachine=(value)
      require 'em-http-request' if value
      @use_eventmachine = value
    end

    # allow params to be read like a hash
    def [](option)
      send(option)
    end
  end
end
