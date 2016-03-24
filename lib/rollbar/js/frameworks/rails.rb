module Rollbar
  module Js
    module Frameworks
      class Rails
        attr_accessor :prepared

        alias prepared? prepared

        def prepare
          return if prepared?

          if secure_headers?
            insert_middleware_after_secure_headers
          else
            insert_middleware
          end

          self.prepared = true
        end

        def insert_middleware_after_secure_headers
          instance = self

          Rollbar::Railtie.initializer 'rollbar.middleware.js.frameworks.rails', :after => 'secure_headers.middleware' do |_app|
            instance.insert_middleware
          end
        end

        def insert_middleware
          require 'rollbar/js/middleware'

          config = {
            :options => Rollbar.configuration.js_options,
            :enabled => Rollbar.configuration.js_enabled
          }
          rails_config.middleware.use(::Rollbar::Js::Middleware, config)
        end

        def secure_headers?
          defined?(::SecureHeaders)
        end

        def rails_config
          ::Rails.configuration
        end
      end
    end
  end
end
