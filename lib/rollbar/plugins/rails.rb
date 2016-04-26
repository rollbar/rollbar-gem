Rollbar.plugins.define('rails32-errors') do
  dependency { defined?(Rails::VERSION) && Rails::VERSION::MAJOR >= 3 }
  dependency { Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new('3.2') }

  execute! do
    require 'rollbar/plugins/rails/railtie32'
  end
end

Rollbar.plugins.define('rails30-errors') do
  dependency { defined?(Rails::VERSION) && Rails::VERSION::MAJOR >= 3 }
  dependency { Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new('3.2') }

  execute! do
    require 'rollbar/plugins/rails/railtie30'
  end
end

Rollbar.plugins.define('rails-rollbar.js') do
  dependency { configuration.js_enabled }

  execute do
    module Rollbar
      module Js
        module Frameworks
          class Rails
            def load
              if secure_headers_middleware?
                insert_middleware_after_secure_headers
              else
                insert_middleware
              end
            end

            def insert_middleware_after_secure_headers
              instance = self

              Rollbar::Railtie.initializer 'rollbar.js.frameworks.rails', :after => 'secure_headers.middleware' do |_app|
                instance.insert_middleware
              end
            end

            def insert_middleware
              require 'rollbar/middleware/js'

              config = {
                :options => Rollbar.configuration.js_options,
                :enabled => Rollbar.configuration.js_enabled
              }
              rails_config.middleware.use(::Rollbar::Middleware::Js, config)
            end

            def secure_headers_middleware?
              defined?(::SecureHeaders::Middleware)
            end

            def rails_config
              ::Rails.configuration
            end
          end
        end
      end
    end
  end

  execute do
    Rollbar::Js::Frameworks::Rails.new.load
  end
end
