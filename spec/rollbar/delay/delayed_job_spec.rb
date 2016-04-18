require 'spec_helper'

require 'delayed_job'
require 'delayed/worker'
require 'rollbar/delay/delayed_job'
require 'delayed/backend/test'

describe Rollbar::Delay::DelayedJob do
  before do
    Delayed::Backend::Test.prepare_worker
    Delayed::Worker.backend = :test
  end

  describe '.call' do
    let(:payload) { {} }
    it 'calls Rollbar' do
      expect(Rollbar).to receive(:process_from_async_handler).with(payload)

      Rollbar::Delay::DelayedJob.call(payload)
    end
  end
end
