require 'rollbar'
begin
  require 'rack/mock'
rescue LoadError
  puts 'Cannot load rack/mock'
end
require 'logger'

namespace :rollbar do
  desc 'Verify your gem installation by sending a test exception to Rollbar'
  task :test => [:environment] do
    RollbarTest.run
  end
end

# Module to inject into the Rails controllers or rack apps
module RollbarTest # :nodoc:
  def test_rollbar
    puts 'Raising RollbarTestingException to simulate app failure.'

    raise RollbarTestingException.new, 'Testing rollbar with "rake rollbar:test". If you can see this, it works.'
  end

  def self.run
    configure_rails if defined?(Rails)

    exit unless confirmed_token?

    puts 'Testing manual report...'
    Rollbar.error('Test error from rollbar:test')

    return unless defined?(Rack::MockRequest)

    protocol, app = setup_app

    puts 'Processing...'
    env = Rack::MockRequest.env_for("#{protocol}://www.example.com/verify")
    status, = app.call(env)

    puts error_message unless status.to_i == 500
  end

  def self.configure_rails
    Rails.logger = if defined?(ActiveSupport::TaggedLogging)
                     ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
                   else
                     Logger.new(STDOUT)
                   end

    Rails.logger.level = Logger::DEBUG
    Rollbar.preconfigure do |config|
      config.logger = Rails.logger
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

  def self.draw_rails_route
    Rails.application.routes_reloader.execute_if_updated
    Rails.application.routes.draw do
      get 'verify' => 'rollbar_test#verify', :as => 'verify'
    end
  end

  def self.authlogic_config
    # from http://stackoverflow.com/questions/5270835/authlogic-activation-problems
    return unless defined?(Authlogic)

    Authlogic::Session::Base.controller = Authlogic::ControllerAdapters::RailsAdapter.new(self)
  end

  def self.setup_app
    puts 'Setting up the test app.'

    if defined?(Rails)
      draw_rails_route

      authlogic_config

      protocol = defined?(Rails.application.config.force_ssl && Rails.application.config.force_ssl) ? 'https' : 'http'
      [protocol, Rails.application]
    else
      ['http', rack_app]
    end
  end

  def self.rack_app
    Class.new do
      include RollbarTest

      def self.call(_env)
        new.test_rollbar
      end
    end
  end

  def self.error_message
    'Test failed! You may have a configuration issue, or you could be using a gem that\'s blocking the test. Contact support@rollbar.com if you need help troubleshooting.'
  end
end

class RollbarTestingException < RuntimeError; end

class RollbarTestController < ActionController::Base # :nodoc:
  include RollbarTest

  def verify
    test_rollbar
  end

  def logger
    nil
  end
end
