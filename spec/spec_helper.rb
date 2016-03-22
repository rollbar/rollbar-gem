require 'rubygems'

ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'
require File.expand_path('../dummyapp/config/environment', __FILE__)
require 'rspec/rails'
require 'database_cleaner'

begin
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
rescue LoadError
end

namespace :dummy do
  load 'spec/dummyapp/Rakefile'
end

if ENV['TRAVIS_JDK_VERSION'] == 'oraclejdk7'
  require 'rollbar/configuration'
  Rollbar::Configuration::DEFAULT_ENDPOINT = 'https://api-alt.rollbar.com/api/1/item/'
end

Rake::Task['dummy:db:setup'].invoke

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.extend(Helpers)
  config.include(NotifierHelpers)
  config.include(FixtureHelpers)
  config.include(EncodingHelpers)

  config.color = true
  config.formatter = 'documentation'

  config.use_transactional_fixtures = true
  config.order = 'random'

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

  config.infer_spec_type_from_file_location! if config.respond_to?(:infer_spec_type_from_file_location!)
  config.backtrace_exclusion_patterns = [/gems\/rspec-.*/]
end
