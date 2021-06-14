require 'spec_helper'
require 'rollbar/delay/resque'

describe Rollbar::Delay::Resque do
  describe '.call' do
    let(:payload) do
      { :key => 'value' }
    end

    let(:loaded_hash) do
      Rollbar::JSON.load(Rollbar::JSON.dump(payload))
    end

    before do
      allow(Resque).to receive(:inline?).and_return(true)
    end

    it 'process the payload' do
      expect(Rollbar).to receive(:process_from_async_handler).with(loaded_hash)
      described_class.call(payload)
    end

    context 'with exceptions processing payload' do
      let(:exception) { Exception.new }

      before do
        expect(Rollbar).to receive(:process_from_async_handler)
          .with(loaded_hash)
          .and_raise(exception)
      end

      it 'raises an exception' do
        expect do
          described_class.call(payload)
        end.to raise_error(exception)
      end
    end
  end
end
