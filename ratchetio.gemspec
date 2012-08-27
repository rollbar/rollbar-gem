# -*- encoding: utf-8 -*-
require File.expand_path('../lib/ratchetio/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Brian Rue"]
  gem.email         = ["brian@ratchet.io"]
  gem.description   = %q{Official ruby gem for Ratchet.io}
  gem.summary       = %q{Reports exceptions to Ratchet.io}
  gem.homepage      = "https://ratchet.io/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ratchetio"
  gem.require_paths = ["lib"]
  gem.version       = Ratchetio::VERSION

  #gem.add_development_dependency "rspec", "~> 2.6"
end
