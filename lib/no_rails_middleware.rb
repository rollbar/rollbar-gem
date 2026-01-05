# When required in the application's Gemfile, this prevents the Rollbar
# middleware from being inserted into the Rails middleware stack.
#
# ex:
# `gem 'rollbar', require: ['no_rails_middleware', 'rollbar']`
#
module Rollbar
  NO_RAILS_MIDDLEWARE = true
end
