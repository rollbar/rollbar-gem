require 'ratchetio'

module Ratchetio
  module Rails
    def self.initialize
      rails_logger = if defined?(::Rails.logger)
                       ::Rails.logger
                     elsif defined?(RAILS_DEFAULT_LOGGER)
                       RAILS_DEFAULT_LOGGER
                     end

      Ratchetio.configure do |config|
        config.logger = rails_logger
        config.environment = defined?(::Rails.env) && ::Rails.env || defined?(RAILS_ENV) && RAILS_ENV
        config.root = defined?(::Rails.root) && ::Rails.root || defined?(RAILS_ROOT) && RAILS_ROOT
        config.framework = defined?(::Rails.version) && "Rails: #{::Rails.version}" || defined?(::Rails::VERSION::STRING) && "Rails: #{::Rails::VERSION::STRING}"
      end
    end
  end
end

Ratchetio::Rails.initialize
