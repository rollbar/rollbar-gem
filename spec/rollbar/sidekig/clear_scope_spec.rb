require 'spec_helper'

require 'sidekiq'

Rollbar.plugins.load!

describe Rollbar::Sidekiq::ClearScope, :reconfigure_notifier => false do
  describe '#call' do
    let(:middleware_block) { proc {} }

    it 'sends the error to Rollbar::Sidekiq.handle_exception' do
      expect(Rollbar).to receive(:reset_notifier!)

      subject.call(nil, nil, nil, &middleware_block)
    end
  end
end
