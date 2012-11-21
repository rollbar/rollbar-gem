# -*- encoding: utf-8 -*-
require File.expand_path('../lib/ratchetio/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Brian Rue"]
  gem.email         = ["brian@ratchet.io"]
  gem.description   = %q{Rails plugin to catch and send exceptions to Ratchet.io}
  gem.summary       = %q{Reports exceptions to Ratchet.io}
  gem.homepage      = "https://github.com/ratchetio/ratchetio-gem"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ratchetio"
  gem.require_paths = ["lib"]
  gem.version       = Ratchetio::VERSION

  gem.add_development_dependency 'rspec-rails', '~> 2.12'
  gem.add_development_dependency 'rails', '~> 3.2.9'
  gem.add_development_dependency 'sqlite3'
  gem.add_development_dependency 'jquery-rails'
  gem.add_development_dependency 'jquery-rails'

  gem.add_development_dependency 'rspec-rails', '>= 2.11.4'
  gem.add_development_dependency 'database_cleaner', '>= 0.9.1'
  gem.add_development_dependency 'email_spec', '>= 1.4.0'
  gem.add_development_dependency 'cucumber-rails', '>= 1.3.0'
  gem.add_development_dependency 'launchy', '>= 2.1.2'
  #gem.add_development_dependency 'capybara', '>= 1.1.3'
  gem.add_development_dependency 'factory_girl_rails', '>= 4.1.0'
  gem.add_development_dependency 'devise', '>= 2.1.2'
  gem.add_development_dependency 'quiet_assets', '>= 1.0.1'

end
