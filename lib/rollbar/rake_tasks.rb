require 'rollbar'

namespace :rollbar do
  desc "Verify your gem installation by sending a test exception to Rollbar"
  task :test => [:environment] do
    Rails.logger = defined?(ActiveSupport::TaggedLogging) ?
      ActiveSupport::TaggedLogging.new(Logger.new(STDOUT)) :
      Logger.new(STDOUT)

    Rails.logger.level = Logger::DEBUG
    Rollbar.configure do |config|
      config.logger = Rails.logger
    end

    class RollbarTestingException < RuntimeError; end

    unless Rollbar.configuration.access_token
      puts "Rollbar needs an access token configured. Check the README for instructions."
      exit
    end

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
      prepend_before_filter :test_rollbar
      def test_rollbar
        puts "Raising RollbarTestingException to simulate app failure."
        raise RollbarTestingException.new, 'Testing rollbar with "rake rollbar:test". If you can see this, it works.'
      end

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

    puts "Processing..."
    env = Rack::MockRequest.env_for("/verify")

    Rails.application.call(env)
  end
end
