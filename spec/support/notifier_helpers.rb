module NotifierHelpers
  def reconfigure_notifier
    Rollbar.clear_notifier!

    Rollbar.reconfigure do |config|
      # special test access token
      config.access_token = test_access_token
      config.logger = ::Rails.logger
      config.logger_level = :debug
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
      config.logger_level = :debug
      config.environment = defined?(::Rails.env) && ::Rails.env ||
                           defined?(RAILS_ENV) && RAILS_ENV
      config.root = defined?(::Rails.root) && ::Rails.root ||
                    defined?(RAILS_ROOT) && RAILS_ROOT
      version = defined?(::Rails.version) && ::Rails.version ||
                defined?(::Rails::VERSION::STRING) && ::Rails::VERSION::STRING
      config.framework = "Rails: #{version}"
    end
  end

  def test_access_token
    'bfec94a1ede64984b862880224edd0ed'
  end

  def reset_configuration
    Rollbar.reconfigure do |config|
    end
  end

  def clear_proxy_env_vars
    env_vars = {}
    proxy_env_vars.each do |var|
      env_vars[var] = ENV.delete(var)
    end
    env_vars
  end

  def restore_proxy_env_vars(env_vars)
    proxy_env_vars.each do |var|
      ENV[var] = env_vars[var]
    end
  end

  def proxy_env_vars
    %w[http_proxy HTTP_PROXY https_proxy HTTPS_PROXY]
  end
end
