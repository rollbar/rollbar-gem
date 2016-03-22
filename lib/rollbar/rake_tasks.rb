require 'rollbar'
require 'rack/mock'

namespace :rollbar do
  desc "Verify your gem installation by sending a test exception to Rollbar"
  task :test => [:environment] do
    if defined?(Rails)
      Rails.logger = defined?(ActiveSupport::TaggedLogging) ?
        ActiveSupport::TaggedLogging.new(Logger.new(STDOUT)) :
        Logger.new(STDOUT)

      Rails.logger.level = Logger::DEBUG
      Rollbar.preconfigure do |config|
        config.logger = Rails.logger
      end
    end

    class RollbarTestingException < RuntimeError; end

    unless Rollbar.configuration.access_token
      puts "Rollbar needs an access token configured. Check the README for instructions."
      exit
    end

    Rollbar.error('Test error from rollbar:test')

    module RollbarTest
      def test_rollbar
        puts "Raising RollbarTestingException to simulate app failure."
        raise RollbarTestingException.new, 'Testing rollbar with "rake rollbar:test". If you can see this, it works.'
      end
    end

    if defined?(Rails)
      begin
        require './app/controllers/application_controller'
      rescue LoadError
      end

      unless defined?(ApplicationController)
        puts "No ApplicationController found, using ActionController::Base instead"
        class ApplicationController < ActionController::Base; end
      end

      puts "Setting up the controller."
      class ApplicationController
        include TestRollbar

        prepend_before_filter :test_rollbar

        def verify
        end

        def logger
          nil
        end
      end

      class RollbarTestController < ApplicationController; end

      Rails.application.routes_reloader.execute_if_updated
      Rails.application.routes.draw do
        get 'verify' => 'application#verify', :as => 'verify'
      end

      # from http://stackoverflow.com/questions/5270835/authlogic-activation-problems
      if defined? Authlogic
        Authlogic::Session::Base.controller = Authlogic::ControllerAdapters::RailsAdapter.new(self)
      end

      protocol = (defined? Rails.application.config.force_ssl && Rails.application.config.force_ssl) ? 'https' : 'http'
      app = Rails.application
    else
      protocol = 'http'
      app = Class.new do
        include RollbarTest

        def self.call(_env)
          new.test_rollbar
        end
      end
    end

    puts "Processing..."
    env = Rack::MockRequest.env_for("#{protocol}://www.example.com/verify")
    status, = app.call(env)

    unless status.to_i == 500
      puts "Test failed! You may have a configuration issue, or you could be using a gem that's blocking the test. Contact support@rollbar.com if you need help troubleshooting."
    end
  end
end
