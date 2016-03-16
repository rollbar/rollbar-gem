# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rollbar/version', __FILE__)


Gem::Specification.new do |gem|
  is_jruby = defined?(JRUBY_VERSION) || (defined?(RUBY_ENGINE) && 'jruby' == RUBY_ENGINE)

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

  gem.add_development_dependency 'oj', '~> 2.12.14' unless is_jruby

  gem.add_development_dependency 'sidekiq', '>= 2.13.0' if RUBY_VERSION != '1.8.7'
  if RUBY_VERSION.start_with?('1.9')
    gem.add_development_dependency 'sucker_punch', '~> 1.0'
  elsif RUBY_VERSION.start_with?('2')
    gem.add_development_dependency 'sucker_punch', '~> 2.0'
  end

  gem.add_development_dependency 'sinatra'
  gem.add_development_dependency 'resque'
  gem.add_development_dependency 'delayed_job'
  gem.add_development_dependency 'redis'
  gem.add_runtime_dependency 'multi_json'
end
