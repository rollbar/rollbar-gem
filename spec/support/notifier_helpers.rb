module NotifierHelpers
  def reconfigure_notifier
    Rollbar.clear_notifier!

    Rollbar.reconfigure do |config|
      # special test access token
      config.access_token = test_access_token
      config.logger = ::Rails.logger
      config.root = ::Rails.root
      config.framework = "Rails: #{::Rails::VERSION::STRING}"
      config.open_timeout = 60
      config.request_timeout = 60
    end
  end

  def preconfigure_rails_notifier
    rails_logger = if defined?(::Rails.logger)
                     ::Rails.logger
                   elsif defined?(RAILS_DEFAULT_LOGGER)
                     RAILS_DEFAULT_LOGGER
                   end

    Rollbar.preconfigure do |config|
      config.logger = rails_logger
      config.environment = defined?(::Rails.env) && ::Rails.env || defined?(RAILS_ENV) && RAILS_ENV
      config.root = defined?(::Rails.root) && ::Rails.root || defined?(RAILS_ROOT) && RAILS_ROOT
      config.framework = defined?(::Rails.version) && "Rails: #{::Rails.version}" || defined?(::Rails::VERSION::STRING) && "Rails: #{::Rails::VERSION::STRING}"
    end
  end

  def test_access_token
    'bfec94a1ede64984b862880224edd0ed'
  end

  def reset_configuration
    Rollbar.reconfigure do |config|
    end
  end
end
