require 'rollbar'
begin
  require 'rack/mock'
rescue LoadError
end
require 'logger'

namespace :rollbar do
  desc 'Verify your gem installation by sending a test exception to Rollbar'
  task :test => [:environment] do
    if defined?(Rails)
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

    class RollbarTestingException < RuntimeError; end

    unless Rollbar.configuration.access_token
      puts 'Rollbar needs an access token configured. Check the README for instructions.'

      exit
    end

    puts 'Testing manual report...'
    Rollbar.error('Test error from rollbar:test')

    # Module to inject into the Rails controllers or
    # rack apps
    module RollbarTest
      def test_rollbar
        puts 'Raising RollbarTestingException to simulate app failure.'

        raise RollbarTestingException.new, 'Testing rollbar with "rake rollbar:test". If you can see this, it works.'
      end
    end

    if defined?(Rack::MockRequest)
      if defined?(Rails)
        begin
          require './app/controllers/application_controller'
        rescue LoadError
        end

        unless defined?(ApplicationController)
          puts 'No ApplicationController found, using ActionController::Base instead'
          class ApplicationController < ActionController::Base; end
        end

        puts 'Setting up the controller.'

        class RollbarTestController < ApplicationController
          include RollbarTest

          def verify
            test_rollbar
          end

          def logger
            nil
          end
        end

        Rails.application.routes_reloader.execute_if_updated
        Rails.application.routes.draw do
          get 'verify' => 'rollbar_test#verify', :as => 'verify'
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

      puts 'Processing...'
      env = Rack::MockRequest.env_for("#{protocol}://www.example.com/verify")
      status, = app.call(env)

      unless status.to_i == 500
        puts 'Test failed! You may have a configuration issue, or you could be using a gem that\'s blocking the test. Contact support@rollbar.com if you need help troubleshooting.'
      end
    end
  end
end
