require 'spec_helper'

if defined?(RSpecCommand)
  require 'rails/rollbar_runner'

  describe 'rollbar-rails-runner', :if => RUBY_VERSION < '2.6' do
    command %q[rollbar-rails-runner "puts 'hello'"]
    its(:stdout) do
      is_expected.to include('hello')
    end
  end
end
