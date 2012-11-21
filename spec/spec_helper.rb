#require 'rspec'
#require 'ratchetio'

require 'rubygems'

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../dummyapp/config/environment', __FILE__)
require 'rspec/rails'
require 'factory_girl_rails'
require 'database_cleaner'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| puts f; require f }
FactoryGirl.definition_file_paths = [ File.join(Rails.root, '../factories') ]

RSpec.configure do |config|
  config.color_enabled = true
  config.formatter = 'documentation'

  config.use_transactional_fixtures = true
  config.order = "random"
  
  config.before(:suite) do
    FactoryGirl.reload
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
    DatabaseCleaner.clean
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

