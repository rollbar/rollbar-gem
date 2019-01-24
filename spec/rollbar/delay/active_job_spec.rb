require 'spec_helper'
require 'rollbar/delay/active_job'

describe Rollbar::Delay::ActiveJob do
  describe '.call' do
    let(:payload) { {} }
    it 'calls Rollbar' do
      expect(Rollbar).to receive(:process_from_async_handler).with(payload)

      Rollbar::Delay::ActiveJob.call(payload)
    end
  end
end
