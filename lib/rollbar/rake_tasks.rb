
namespace :rollbar do
  desc 'Verify your gem installation by sending a test message to Rollbar'
  task :test => [:environment] do
    rollbar_dir = Gem.loaded_specs['rollbar'].full_gem_path
    require "#{rollbar_dir}/lib/rollbar/rollbar_test"

    RollbarTest.run
  end
end
