# This Gemfile is compatible with Ruby 2.5.0 or greater. To test with
# earlier Rubies, use the appropriate Gemfile from the ./gemfiles/ dir.
ruby '3.3.6'

source 'https://rubygems.org'

# Used by spec/commands/rollbar_rails_runner_spec, and can be used whenever a
# new process is created during tests. (Testing rake tasks, for example.)
# This is a workaround for ENV['BUNDLE_GEMFILE'] not working as expected on Travis.
# We use the ||= assignment because Travis loads the gemfile twice, the second time
# with the wrong gemfile path.
ENV['CURRENT_GEMFILE'] ||= __FILE__

is_jruby = defined?(JRUBY_VERSION) || (defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby')

GEMFILE_RAILS_VERSION = '~> 8.0.0'.freeze
gem 'activerecord-jdbcsqlite3-adapter', platform: :jruby
gem 'jruby-openssl', platform: :jruby
gem 'rails', GEMFILE_RAILS_VERSION
gem 'rake'

if GEMFILE_RAILS_VERSION < '6.0'
  gem 'rspec-rails', '~> 3.4'
elsif GEMFILE_RAILS_VERSION < '7.0'
  gem 'rspec-rails', '~> 4.0.2'
else
  gem 'rspec-rails', '~> 6.0.3'
end

if GEMFILE_RAILS_VERSION >= '8.0'
  gem 'sqlite3', '~> 2.0', platform: [:ruby, :mswin, :mingw]
elsif GEMFILE_RAILS_VERSION < '6.0'
  gem 'sqlite3', '< 1.4.0', platform: [:ruby, :mswin, :mingw]
else
  gem 'sqlite3', '~> 1.4', platform: [:ruby, :mswin, :mingw]
end

gem 'sidekiq', '>= 6.4.0'

platforms :rbx do
  gem 'minitest'
  gem 'racc'
  gem 'rubinius-developer_tools'
end

gem 'capistrano', require: false
gem 'shoryuken'
gem 'simplecov'
gem 'sucker_punch', '~> 2.0'

unless is_jruby
  # JRuby doesn't support fork, which is required for this test helper.
  gem 'rspec-command'
end

gem 'aws-sdk-sqs'

if GEMFILE_RAILS_VERSION >= '5.2'
  gem 'database_cleaner'
elsif GEMFILE_RAILS_VERSION.between?('5.0', '5.2')
  gem 'database_cleaner', '~> 1.8.4'
elsif GEMFILE_RAILS_VERSION < '5.0'
  gem 'database_cleaner', '~> 1.0.0'
end

if GEMFILE_RAILS_VERSION < '6.0'
  gem 'delayed_job', require: false
else
  gem 'delayed_job', '~> 4.1', require: false
end

gem 'generator_spec'
gem 'redis', '<= 4.8.0'
gem 'resque', '< 2.0.0'
gem 'rubocop', '1.15.0', require: false # pin specific version, update manually
gem 'rubocop-performance', require: false
gem 'secure_headers', '~> 6.3.2', require: false
gem 'sinatra'
gem 'webmock', require: false
gemspec
