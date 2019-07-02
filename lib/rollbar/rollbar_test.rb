require 'rollbar'
begin
  require 'rack/mock'
rescue LoadError
  puts 'Cannot load rack/mock'
end
require 'logger'

# Module to inject into the Rails controllers or rack apps
module RollbarTest # :nodoc:
  def test_rollbar
    puts 'Raising RollbarTestingException to simulate app failure.'

    raise RollbarTestingException.new, ::RollbarTest.success_message
  end

  def self.run
    return unless confirmed_token?

    configure_rails if defined?(Rails)

    puts 'Testing manual report...'
    Rollbar.error('Test error from rollbar:test')

    return unless defined?(Rack::MockRequest)

    protocol, app = setup_app

    puts 'Processing...'
    env = Rack::MockRequest.env_for("#{protocol}://www.example.com/verify", 'REMOTE_ADDR' => '127.0.0.1')
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

  def self.authlogic_config
    # from http://stackoverflow.com/questions/5270835/authlogic-activation-problems
    return unless defined?(Authlogic)

    Authlogic::Session::Base.controller = Authlogic::ControllerAdapters::RailsAdapter.new(self)
  end

  def self.setup_app
    puts 'Setting up the test app.'

    if defined?(Rails)
      app = rails_app

      draw_rails_route(app)

      authlogic_config

      [rails_protocol(app), app]
    else
      ['http', rack_app]
    end
  end

  def self.rails_app
    # The setup below is needed for Rails 5.x, but not for Rails 4.x and below.
    # (And fails on Rails 4.x in various ways depending on the exact version.)
    return Rails.application if Rails.version < '5.0.0'

    # Spring now runs by default in development on all new Rails installs. This causes
    # the new `/verify` route to not get picked up if `config.cache_classes == false`
    # which is also a default in development env.
    #
    # `config.cache_classes` needs to be set, but the only possible time is at app load,
    # so here we clone the default app with an updated config.
    #
    config = Rails.application.config
    config.cache_classes = true

    # Make a copy of the app, so the config can be updated.
    Rails.application.class.name.constantize.new(:config => config)
  end

  def self.draw_rails_route(app)
    app.routes_reloader.execute_if_updated
    app.routes.draw do
      get 'verify' => 'rollbar_test#verify', :as => 'verify'
    end
  end

  def self.rails_protocol(app)
    defined?(app.config.force_ssl && app.config.force_ssl) ? 'https' : 'http'
  end

  def self.rack_app
    Class.new do
      include RollbarTest

      def self.call(_env)
        new.test_rollbar
      end
    end
  end

  def self.token_error_message
    'Rollbar needs an access token configured. Check the README for instructions.'
  end

  def self.error_message
    'Test failed! You may have a configuration issue, or you could be using a gem that\'s blocking the test. Contact support@rollbar.com if you need help troubleshooting.'
  end

  def self.success_message
    'Testing rollbar with "rake rollbar:test". If you can see this, it works.'
  end
end

class RollbarTestingException < RuntimeError; end

if defined?(Rails)
  class RollbarTestController < ActionController::Base # :nodoc:
    include RollbarTest

    def verify
      test_rollbar
    end

    def logger
      nil
    end
  end
end
