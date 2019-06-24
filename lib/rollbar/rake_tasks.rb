namespace :rollbar do
  desc 'Verify your gem installation by sending a test exception to Rollbar'
  task :test => [:environment] do
    require './verify_setup'
    RollbarTest.run
  end
end
