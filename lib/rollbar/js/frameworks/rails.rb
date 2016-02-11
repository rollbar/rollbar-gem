module Rollbar
  module Js
    module Frameworks
      class Rails
        attr_accessor :prepared

        alias prepared? prepared

        def prepare
          return if prepared?

          require 'rollbar/js/middleware'

          config = {
            :options => Rollbar.configuration.js_options,
            :enabled => Rollbar.configuration.js_enabled
          }
          rails_config.middleware.use(::Rollbar::Js::Middleware, config)

          self.prepared = true
        end

        def rails_config
          ::Rails.configuration
        end
      end
    end
  end
end
