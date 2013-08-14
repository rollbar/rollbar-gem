# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rollbar/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Brian Rue"]
  gem.email         = ["brian@rollbar.com"]
  gem.description   = %q{Rails plugin to catch and send exceptions to Rollbar}
  gem.summary       = %q{Reports exceptions to Rollbar}
  gem.homepage      = "https://github.com/rollbar/rollbar-gem"
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(spec)/})
  gem.name          = "rollbar"
  gem.require_paths = ["lib"]
  gem.version       = Rollbar::VERSION

  gem.add_runtime_dependency 'multi_json', '~> 1.5'

  gem.add_development_dependency 'rails', '>= 3.0.0'
  gem.add_development_dependency 'rspec-rails', '~> 2.12.0'
  gem.add_development_dependency 'database_cleaner', '~> 1.0.0'
  gem.add_development_dependency 'girl_friday', '>= 0.11.1'
  gem.add_development_dependency 'sucker_punch', '>= 1.0.0'
  gem.add_development_dependency 'genspec', '>= 0.2.7'
end
