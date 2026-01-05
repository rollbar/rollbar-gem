require 'rails/railtie'
require 'rollbar/plugins/rails/railtie_mixin'

module Rollbar
  class Railtie < ::Rails::Railtie
    include Rollbar::RailtieMixin

    initializer 'rollbar.middleware.rails' do |app|
      require 'rollbar/middleware/rails/rollbar'
      require 'rollbar/middleware/rails/show_exceptions'

      unless defined?(Rollbar::NO_RAILS_MIDDLEWARE) && Rollbar::NO_RAILS_MIDDLEWARE
        app.config.middleware.insert_after ActionDispatch::DebugExceptions,
                                           Rollbar::Middleware::Rails::RollbarMiddleware
      end
      ActionDispatch::DebugExceptions.send(:include,
                                           Rollbar::Middleware::Rails::ShowExceptions)
    end
  end
end
