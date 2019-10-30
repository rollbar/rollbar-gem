begin
  require 'simplecov'
  require 'codacy-coverage'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [
    SimpleCov::Formatter::HTMLFormatter,
    Codacy::Formatter
  ]

  SimpleCov.start do
    add_filter '/spec/'
  end

  # Skip Codacy when running locally, to display the Simplecov summary in the console
  # and write an updated coverage/index.html
  Codacy::Reporter.start if Codacy::Formatter.new.send :should_run?
rescue LoadError
end

require 'rubygems'

ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'
require File.expand_path('../dummyapp/config/environment', __FILE__)
require 'rspec/rails'
require 'database_cleaner'

# Needed for rollbar-rails-runner (or anything else that doesn't have Rails.root)
ENV['DUMMYAPP_PATH'] = "#{File.dirname(__FILE__)}/dummyapp"

begin
  require 'webmock/rspec'
  WebMock.disable_net_connect!(:allow => 'codeclimate.com')
rescue LoadError
end

namespace :dummy do
  load 'spec/dummyapp/Rakefile'
end

if ENV['TRAVIS_JDK_VERSION'] == 'oraclejdk7'
  require 'rollbar/configuration'
  Rollbar::Configuration::DEFAULT_ENDPOINT = 'https://api-alt.rollbar.com/api/1/item/'.freeze
end

if Gem::Version.new(Rails.version) < Gem::Version.new('5.0')
  Rake::Task['dummy:db:setup'].invoke
else
  Rake::Task['dummy:db:test:prepare'].invoke
end

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
  config.expect_with(:rspec) do |c|
    c.syntax = [:should, :expect]
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = [:should, :expect]
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
    DatabaseCleaner.clean
    Rollbar.clear_notifier!

    stub_request(:any, /api.rollbar.com/).to_rack(RollbarAPI.new) if defined?(WebMock)
    stub_request(:post, %r{api.rollbar.com/api/[0-9]/deploy/$}).to_rack(DeployAPI::Report.new) if defined?(WebMock)
    stub_request(:patch, %r{api.rollbar.com/api/[0-9]/deploy/[0-9]+}).to_rack(DeployAPI::Update.new) if defined?(WebMock)
  end

  config.after do
    DatabaseCleaner.clean
  end

  config.infer_spec_type_from_file_location! if config.respond_to?(:infer_spec_type_from_file_location!)
  config.backtrace_exclusion_patterns = [%r{gems/rspec-.*}]

  config.include RSpecCommand if defined?(RSpecCommand)
end
