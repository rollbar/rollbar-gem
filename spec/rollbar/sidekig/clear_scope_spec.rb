require 'spec_helper'

unless RUBY_VERSION == '1.8.7'
  require 'sidekiq'
end

Rollbar.plugins.load!

describe Rollbar::Sidekiq::ClearScope, :reconfigure_notifier => false do
  describe '#call' do
    let(:middleware_block) { proc{} }

    it 'sends the error to Rollbar::Sidekiq.handle_exception' do
      expect(Rollbar).to receive(:reset_notifier!)

      subject.call(nil, nil, nil, &middleware_block)
    end
  end
end unless RUBY_VERSION == '1.8.7'
