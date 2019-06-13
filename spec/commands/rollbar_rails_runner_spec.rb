require 'spec_helper'

if defined?(RSpecCommand)
  require 'rails/rollbar_runner'

  # rspec_command and/or mixlib/shellout are no longer picking up the
  # environment correctly with Ruby 2.6.x on travis. Not sure why yet.
  describe 'rollbar-rails-runner', :if => RUBY_VERSION < '2.6' do
    # We set ENV['CURRENT_GEMFILE'] in the gemfile because Travis doesn't set
    # ENV['BUNDLE_GEMFILE'] correctly.
    command %q[rollbar-rails-runner "puts 'hello'"]
    environment :BUNDLE_GEMFILE => ENV['CURRENT_GEMFILE']
    its(:stdout) do
      is_expected.to include('hello')
    end
  end
end
