require 'rollbar'

module RollbarTest # :nodoc:
  def self.run
    return unless confirmed_token?

    puts 'Test sending to Rollbar...'
    result = Rollbar.info('Test message from rollbar:test')

    if result == 'error'
      puts error_message
    else
      puts success_message
    end
  end

  def self.confirmed_token?
    return true if Rollbar.configuration.access_token

    puts token_error_message

    false
  end

  def self.token_error_message
    'Rollbar needs an access token configured. Check the README for instructions.'
  end

  def self.error_message
    'Test failed! You may have a configuration issue, or you could be using a ' \
    'gem that\'s blocking the test. Contact support@rollbar.com if you need ' \
    'help troubleshooting.'
  end

  def self.success_message
    'Testing rollbar with "rake rollbar:test". If you can see this, it works.'
  end
end
