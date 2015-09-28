# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rollbar/version', __FILE__)

def jruby?
  defined?(JRUBY_VERSION) || (defined?(RUBY_ENGINE) && 'jruby' == RUBY_ENGINE)
end

Gem::Specification.new do |gem|
  gem.authors       = ["Rollbar, Inc."]
  gem.email         = ["support@rollbar.com"]
  gem.description   = %q{Easy and powerful exception tracking for Ruby}
  gem.executables   = ['rollbar-rails-runner']
  gem.summary       = %q{Reports exceptions to Rollbar}
  gem.homepage      = "https://rollbar.com"
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(spec)/})
  gem.name          = "rollbar"
  gem.require_paths = ["lib"]
  gem.version       = Rollbar::VERSION

  gem.add_development_dependency 'rails', '>= 3.0.0'
  gem.add_development_dependency 'rspec-rails', '>= 2.14.0'
  gem.add_development_dependency 'database_cleaner', '~> 1.0.0'
  gem.add_development_dependency 'girl_friday', '>= 0.11.1'
  gem.add_development_dependency 'sucker_punch', '>= 1.0.0' if RUBY_VERSION != '1.8.7'
  gem.add_development_dependency 'sidekiq', '>= 2.13.0' if RUBY_VERSION != '1.8.7'
  gem.add_development_dependency 'genspec', '>= 0.2.8'
  gem.add_development_dependency 'sinatra'
  gem.add_development_dependency 'resque'
  gem.add_development_dependency 'delayed_job'
  gem.add_development_dependency 'rake', '>= 0.9.0'
  gem.add_development_dependency 'redis'
  gem.add_runtime_dependency     'multi_json'
  gem.add_development_dependency 'oj', '~> 2.12.14' unless jruby?
end
