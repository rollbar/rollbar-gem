require 'spec_helper'
require 'rollbar/delay/resque'

describe Rollbar::Delay::Resque do
  describe '.call' do
    let(:payload) do
      { :key => 'value' }
    end

    before do
      allow(Resque).to receive(:inline?).and_return(true)
    end

    it 'process the payload' do
      loaded_hash = MultiJson.load(MultiJson.dump(payload))

      expect(Rollbar).to receive(:process_payload).with(loaded_hash)
      described_class.call(payload)
    end
  end
end
