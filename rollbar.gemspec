# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rollbar/version', __FILE__)

Gem::Specification.new do |gem|
  is_jruby = defined?(JRUBY_VERSION) || (defined?(RUBY_ENGINE) && 'jruby' == RUBY_ENGINE)

  gem.authors       = ['Rollbar, Inc.']
  gem.email         = ['support@rollbar.com']
  gem.description   = %q{Easy and powerful exception tracking for Ruby}
  gem.executables   = ['rollbar-rails-runner']
  gem.summary       = %q{Reports exceptions to Rollbar}
  gem.homepage      = 'https://rollbar.com'
  gem.license       = 'MIT'
  gem.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  gem.name          = 'rollbar'
  gem.require_paths = ['lib']
  gem.required_ruby_version = '>= 1.9.3'
  gem.version       = Rollbar::VERSION

  gem.add_runtime_dependency 'multi_json'

  if s.respond_to?(:metadata)
    s.metadata['changelog_uri'] = 'https://github.com/rollbar/rollbar-gem/releases'
    s.metadata['source_code_uri'] = 'https://github.com/rollbar/rollbar-gem'
    s.metadata['bug_tracker_uri'] = 'https://github.com/rollbar/rollbar-gem/issues'
    s.metadata['homepage_uri'] = 'https://rollbar.com/'
    s.metadata['documentation_uri'] = 'https://docs.rollbar.com/docs/ruby'
  end
end
