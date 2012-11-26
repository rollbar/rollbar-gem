require 'logger'

module Ratchetio
  class Configuration

    attr_accessor :access_token
    attr_accessor :branch
    attr_accessor :default_logger
    attr_accessor :enabled
    attr_accessor :endpoint
    attr_accessor :environment
    attr_accessor :exception_level_filters
    attr_accessor :framework
    attr_accessor :logger
    attr_accessor :person_method
    attr_accessor :person_id_method
    attr_accessor :person_username_method
    attr_accessor :person_email_method
    attr_accessor :root

    DEFAULT_ENDPOINT = 'https://submit.ratchet.io/api/1/item/'

    def initialize
      @default_logger = lambda { Logger.new(STDERR) }
      @enabled = true
      @endpoint = DEFAULT_ENDPOINT
      @framework = 'Plain'
      @logger = Logger.new(STDERR)
      @exception_level_filters = {
        'ActiveRecord::RecordNotFound' => 'warning',
        'AbstractController::ActionNotFound' => 'warning',
        'ActionController::RoutingError' => 'warning'
      }
      @person_method = 'current_user'
      @person_id_method = 'id'
      @person_username_method = 'username'
      @person_email_method = 'email'
    end

    # allow params to be read like a hash
    def [](option)
      send(option)
    end
  end
end
