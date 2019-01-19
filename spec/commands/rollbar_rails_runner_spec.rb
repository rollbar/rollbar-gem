require 'spec_helper'

if defined?(RSpecCommand)
  require 'rails/rollbar_runner'

  describe 'rollbar-rails-runner' do
    # This example works locally, but Travis tries to run the runner process with
    # the wrong Gemfile. Also, neither `echo $BUNDLE_GEMFILE` nor ENV['BUNDLE_GEMFILE']
    # show the correct value when read from within this example.
    command %q(rollbar-rails-runner "puts 'hello'")
    environment :BUNDLE_GEMFILE => ENV['BUNDLE_GEMFILE']
    its(:stdout) do
      skip 'Travis tries to run the runner process with the wrong Gemfile.'
      is_expected.to include('hello')
    end
  end
end
