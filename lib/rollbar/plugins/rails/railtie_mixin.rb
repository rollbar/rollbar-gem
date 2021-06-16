module Rollbar
  module RailtieMixin
    extend ActiveSupport::Concern

    included do
      rake_tasks do
        require 'rollbar/rake_tasks'
      end

      initializer 'rollbar.configuration' do
        config.after_initialize do
          Rollbar.preconfigure do |config|
            config.default_logger = proc { ::Rails.logger }
            config.environment ||= ::Rails.env
            config.root ||= ::Rails.root
            config.framework = "Rails: #{::Rails::VERSION::STRING}"
            config.filepath ||= begin
              if ::Rails.application.class.respond_to?(:module_parent_name)
                "#{::Rails.application.class.module_parent_name}.rollbar"
              else
                "#{::Rails.application.class.parent_name}.rollbar"
              end
            end
          end
        end
      end

      initializer 'rollbar.controller_methods' do
        ActiveSupport.on_load(:action_controller) do
          # lazily load action_controller methods
          require 'rollbar/plugins/rails/controller_methods'
          include Rollbar::Rails::ControllerMethods
        end
      end
    end
  end
end
