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
  dependency { defined?(Rails::VERSION) && Rails::VERSION::MAJOR >= 3 }

  execute! do
    module Rollbar
      module Js
        module Frameworks
          # Adds Rollbar::Middleware::Js to the Rails middleware stack
          # We need to delay the final insert to the last moment since
          # this feature may be disable.
          # But we need to prepare the middleware insert now because
          # we need to use our Rails railtie initializer in case the
          # customer is using SecureHeaders > 3.0
          class Rails
            def load(plugin)
              plugin_execute = plugin_execute_proc_body(plugin)

              return after_secure_headers(&plugin_execute) if secure_headers_middleware?

              plugin_execute.call
            end

            def after_secure_headers(&block)
              Rollbar::Railtie.initializer('rollbar.js.frameworks.rails',
                                           :after => 'secure_headers.middleware', &block)
            end

            def plugin_execute_proc_body(plugin)
              proc do
                plugin.execute do
                  if Rollbar.configuration.js_enabled
                    require 'rollbar/middleware/js'

                    config = {
                      :options => Rollbar.configuration.js_options,
                      :enabled => Rollbar.configuration.js_enabled
                    }
                    ::Rails.configuration.middleware.use(::Rollbar::Middleware::Js,
                                                         config)
                  end
                end
              end
            end

            def secure_headers_middleware?
              begin
                require 'secure_headers'
              rescue LoadError
                # Skip loading
              end

              defined?(::SecureHeaders::Middleware)
            end
          end
        end
      end
    end
  end

  execute! do
    Rollbar::Js::Frameworks::Rails.new.load(self)
  end
end

Rollbar.plugins.define('rails-error-subscriber') do
  dependency { defined?(Rails::VERSION) && Rails::VERSION::MAJOR >= 7 }

  execute! do
    require 'rollbar/plugins/rails/error_subscriber'
  end
end
