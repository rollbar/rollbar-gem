require 'spec_helper'

if defined?(RSpecCommand)
  require 'rails/rollbar_runner'

  describe 'rollbar-rails-runner' do
    # We set ENV['CURRENT_GEMFILE'] in the gemfile because Travis doesn't set
    # ENV['BUNDLE_GEMFILE'] correctly.
    command %q[rollbar-rails-runner "puts 'hello'"]
    environment :BUNDLE_GEMFILE => ENV['CURRENT_GEMFILE']
    its(:stdout) do
      is_expected.to include('hello')
    end
  end
end
