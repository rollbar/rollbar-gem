require 'rollbar'

module Rollbar
  module Rails
    def self.initialize
      rails_logger = if defined?(::Rails.logger)
                       ::Rails.logger
                     elsif defined?(RAILS_DEFAULT_LOGGER)
                       RAILS_DEFAULT_LOGGER
                     end

      Rollbar.configure do |config|
        config.logger = rails_logger
        config.environment = defined?(::Rails.env) && ::Rails.env || defined?(RAILS_ENV) && RAILS_ENV
        config.root = defined?(::Rails.root) && ::Rails.root || defined?(RAILS_ROOT) && RAILS_ROOT
        config.framework = defined?(::Rails.version) && "Rails: #{::Rails.version}" || defined?(::Rails::VERSION::STRING) && "Rails: #{::Rails::VERSION::STRING}"
        config.parameter_filter = defined?(::Rails.application.config.filter_parameters) && ::ActionDispatch::Http::ParameterFilter.new(::Rails.application.config.filter_parameters | Array(config.scrub_fields)) || nil
      end
    end
  end
end

Rollbar::Rails.initialize
