# -*- encoding: utf-8 -*-

require File.expand_path('../lib/rollbar/version', __FILE__)

Gem::Specification.new do |gem|
  _is_jruby = defined?(JRUBY_VERSION) || (defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby')

  gem.authors       = ['Rollbar, Inc.']
  gem.email         = ['support@rollbar.com']
  gem.description   = 'Easy and powerful exception tracking for Ruby'
  gem.executables   = ['rollbar-rails-runner']
  gem.summary       = 'Reports exceptions to Rollbar'
  gem.homepage      = 'https://rollbar.com'
  gem.license       = 'MIT'
  gem.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  gem.files        += ['spec/support/rollbar_api.rb'] # useful helper for app spec/tests.
  gem.name          = 'rollbar'
  gem.require_paths = ['lib']
  gem.required_ruby_version = '>= 1.9.3'
  gem.version = Rollbar::VERSION

  if gem.respond_to?(:metadata)
    gem.metadata['changelog_uri'] = 'https://github.com/rollbar/rollbar-gem/releases'
    gem.metadata['source_code_uri'] = 'https://github.com/rollbar/rollbar-gem'
    gem.metadata['bug_tracker_uri'] = 'https://github.com/rollbar/rollbar-gem/issues'
    gem.metadata['homepage_uri'] = 'https://rollbar.com/'
    gem.metadata['documentation_uri'] = 'https://docs.rollbar.com/docs/ruby'
  end
end
