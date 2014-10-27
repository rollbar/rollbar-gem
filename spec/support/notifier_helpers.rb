module NotifierHelpers
  def reconfigure_notifier
    Rollbar.reconfigure do |config|
      # special test access token
      config.access_token = test_access_token
      config.logger = ::Rails.logger
      config.root = ::Rails.root
      config.framework = "Rails: #{::Rails::VERSION::STRING}"
      config.request_timeout = 60
    end
  end

  def test_access_token
    'aaaabbbbccccddddeeeeffff00001111'
  end

  def reset_configuration
    Rollbar.reconfigure do |config|
    end
  end
end
