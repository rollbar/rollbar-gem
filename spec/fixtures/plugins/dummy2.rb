require 'rollbar/plugins'

Rollbar.plugins.define(:dummy2) do
  dependency { true }
end
