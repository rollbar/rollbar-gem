require 'spec_helper'

ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'
require File.expand_path('../fixtures/dummyapp/config/environment', __FILE__)
require 'rspec/rails'
require 'database_cleaner'

namespace :dummy do
  load 'spec/fixtures/dummyapp/Rakefile'
end

Rake::Task['dummy:db:setup'].invoke

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.color = true
  config.formatter = 'documentation'

  config.use_transactional_fixtures = true
  config.order = "random"

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
    DatabaseCleaner.clean
    Rollbar.reset_notifier!
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
  config.backtrace_exclusion_patterns = [/gems\/rspec-.*/]

  if ENV['SKIP_DUMMY_ROLLBAR'] == 'true'
    config.filter_run(:skip_dummy_rollbar => true)
  else
    config.filter_run_excluding(:skip_dummy_rollbar => true)
  end
end

def local?
  ENV['LOCAL'] == '1'
end
