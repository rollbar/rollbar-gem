source 'https://rubygems.org'

gemspec

gem 'sqlite3',                          :platform => [:ruby, :mswin, :mingw]
gem 'jruby-openssl',                    :platform => :jruby
gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
gem 'appraisal'

gem 'rubysl', '~> 2.0',                 :platform => :rbx
gem 'racc',                             :platform => :rbx
gem 'minitest',                         :platform => :rbx
gem 'rubysl-test-unit',                 :platform => :rbx
gem 'rubinius-developer_tools',         :platform => :rbx

if RUBY_VERSION.chars.first.to_i > 1
  gem 'byebug'
else
  gem 'debugger'
end
