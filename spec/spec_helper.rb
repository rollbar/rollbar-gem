require 'rubygems'

ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'
require File.expand_path('../dummyapp/config/environment', __FILE__)
require 'rspec/rails'
require 'database_cleaner'
require 'genspec'

namespace :dummy do
  load 'spec/dummyapp/Rakefile'
end

Rake::Task['dummy:db:setup'].invoke

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.color_enabled = true
  config.formatter = 'documentation'

  config.use_transactional_fixtures = true
  config.order = "random"

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner.start
    DatabaseCleaner.clean
    Rollbar.reset_notifier!
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

def reset_configuration
  Rollbar.reconfigure do |config|
  end
end

def local?
  ENV['LOCAL'] == '1'
end
