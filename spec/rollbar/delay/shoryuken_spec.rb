require 'spec_helper'
require 'rollbar/delay/shoryuken'

describe Rollbar::Delay::Shoryuken do
  describe '.call' do
    let(:payload) do
      { :key => 'value' }
    end

    let(:loaded_hash) do
      Rollbar::JSON.load(Rollbar::JSON.dump(payload))
    end

    it 'process the payload' do
      Shoryuken.worker_executor = Shoryuken::Worker::InlineExecutor
      expect(Rollbar).to receive(:process_from_async_handler).with(loaded_hash)
      described_class.call(payload)
      Shoryuken.worker_executor = Shoryuken::Worker::DefaultExecutor
    end
  end
end
