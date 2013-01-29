require 'rails'
require 'ratchetio'

module Ratchetio
  class Railtie < ::Rails::Railtie
    rake_tasks do
      require 'ratchetio/rake_tasks'
    end

    config.after_initialize do
      Ratchetio.configure do |config|
        config.logger ||= ::Rails.logger
        config.environment ||= ::Rails.env
        config.root ||= ::Rails.root
        config.framework = "Rails: #{::Rails::VERSION::STRING}"
        config.filepath ||= ::Rails.application.class.parent_name + '.ratchet'
      end

      ActiveSupport.on_load(:action_controller) do
        # lazily load action_controller methods
        require 'ratchetio/rails/controller_methods'
        include Ratchetio::Rails::ControllerMethods
      end

      if defined?(ActionDispatch::DebugExceptions)
        # Rails 3.2.x
        require 'ratchetio/middleware/rails/show_exceptions'
        ActionDispatch::DebugExceptions.send(:include, Ratchetio::Middleware::Rails::ShowExceptions)
      elsif defined?(ActionDispatch::ShowExceptions)
        # Rails 3.0.x and 3.1.x
        require 'ratchetio/middleware/rails/show_exceptions'
        ActionDispatch::ShowExceptions.send(:include, Ratchetio::Middleware::Rails::ShowExceptions)
      end
    end
  end
end

