require 'spec_helper'
require 'rollbar/delay/thread'

describe Rollbar::Delay::Thread do
  describe '.call' do
    let(:payload) { { :key => 'value' } }

    it 'process the payload in a new thread' do
      expect(Rollbar).to receive(:process_payload_safely).with(payload)

      th = described_class.call(payload)
      th.join
    end
  end
end
