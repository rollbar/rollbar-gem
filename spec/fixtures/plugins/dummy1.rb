require 'rollbar/plugins'

Rollbar.plugins.define(:dummy1) do
  dependency { true }
end
