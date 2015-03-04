require 'rails/railtie'
require 'rollbar'

module Rollbar
  class Railtie < ::Rails::Railtie
    rake_tasks do
      require 'rollbar/rake_tasks'
    end

    initializer 'rollbar.middleware.rails' do |app|
      if defined?(ActionDispatch::DebugExceptions)
        # Rails 3.2.x+
        require 'rollbar/middleware/rails/rollbar'
        require 'rollbar/middleware/rails/show_exceptions'

        app.config.middleware.insert_after ActionDispatch::DebugExceptions,
          Rollbar::Middleware::Rails::RollbarMiddleware
        ActionDispatch::DebugExceptions.send(:include, Rollbar::Middleware::Rails::ShowExceptions)
      elsif defined?(ActionDispatch::ShowExceptions)
        # Rails 3.0.x and 3.1.x
        require 'rollbar/middleware/rails/rollbar'
        require 'rollbar/middleware/rails/show_exceptions'

        app.config.middleware.insert_after ActionDispatch::ShowExceptions,
          Rollbar::Middleware::Rails::RollbarMiddleware
        ActionDispatch::ShowExceptions.send(:include, Rollbar::Middleware::Rails::ShowExceptions)
      end
    end

    config.after_initialize do
      Rollbar.preconfigure do |config|
        config.default_logger = proc { ::Rails.logger }
        config.environment ||= ::Rails.env
        config.root ||= ::Rails.root
        config.framework = "Rails: #{::Rails::VERSION::STRING}"
        config.filepath ||= ::Rails.application.class.parent_name + '.rollbar'
      end

      ActiveSupport.on_load(:action_controller) do
        # lazily load action_controller methods
        require 'rollbar/rails/controller_methods'
        include Rollbar::Rails::ControllerMethods
      end
    end
  end
end
