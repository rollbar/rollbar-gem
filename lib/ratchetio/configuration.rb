module Ratchetio
  class Configuration

    attr_accessor :access_token
    attr_accessor :environment
    attr_accessor :root
    attr_accessor :branch
    attr_accessor :framework
    attr_accessor :endpoint
    attr_accessor :exception_level_filters

    attr_accessor :logger

    DEFAULT_ENDPOINT = "https://submit.ratchet.io/api/1/item/"

    def initialize
      @endpoint = DEFAULT_ENDPOINT
      @framework = 'Plain'
      @exception_level_filters = {
        'ActiveRecord::RecordNotFound' => 'warning',
        'AbstractController::ActionNotFound' => 'warning',
        'ActionController::RoutingError' => 'warning'
      }
    end

    # allow params to be read like a hash
    def [](option)
      send(option)
    end
  end
end
