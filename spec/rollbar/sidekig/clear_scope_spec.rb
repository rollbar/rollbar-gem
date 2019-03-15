require 'spec_helper'

require 'sidekiq' unless RUBY_VERSION == '1.8.7'

Rollbar.plugins.load!

unless RUBY_VERSION == '1.8.7'
  describe Rollbar::Sidekiq::ClearScope, :reconfigure_notifier => false do
    describe '#call' do
      let(:middleware_block) { proc {} }

      it 'sends the error to Rollbar::Sidekiq.handle_exception' do
        expect(Rollbar).to receive(:reset_notifier!)

        subject.call(nil, nil, nil, &middleware_block)
      end
    end
  end
end
