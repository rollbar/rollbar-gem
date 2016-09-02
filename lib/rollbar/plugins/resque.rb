Rollbar.plugins.define('resque') do
  require_dependency('resque')

  # We want to have Resque::Failure::Rollbar loaded before
  # possible initializers, so the users can use the class
  # when configuring Rollbar::Failure.backend or
  # Rollbar::Failure::Multiple.classes
  execute! do
    require 'rollbar/plugins/resque/failure'
  end
end
