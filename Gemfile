source 'https://rubygems.org'

gemspec

gem 'appraisal'
gem 'rake', '>= 0.9.0'

gem 'rubysl', '~> 2.0',                 :platform => :rbx
gem 'racc',                             :platform => :rbx
gem 'minitest',                         :platform => :rbx
gem 'rubysl-test-unit',                 :platform => :rbx
gem 'rubinius-developer_tools',         :platform => :rbx

if ENV['LOCAL'] == true
  if RUBY_VERSION.chars.first.to_i > 1
    gem 'byebug'
  else
    gem 'debugger'
  end
end
