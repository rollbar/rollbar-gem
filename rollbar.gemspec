# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rollbar/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Rollbar, Inc."]
  gem.email         = ["support@rollbar.com"]
  gem.description   = %q{Rails plugin to catch and send exceptions to Rollbar}
  gem.summary       = %q{Reports exceptions to Rollbar}
  gem.homepage      = "https://github.com/rollbar/rollbar-gem"
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(spec)/})
  gem.name          = "rollbar"
  gem.require_paths = ["lib"]
  gem.version       = Rollbar::VERSION

  gem.add_runtime_dependency 'multi_json', '~> 1.3'
end
