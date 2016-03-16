require 'spec_helper'

describe Rollbar::Delay::Thread do
  describe '.call' do
    let(:payload) { { :key => 'value' } }

    it 'process the payload in a new thread' do
      expect(Rollbar).to receive(:process_from_async_handler).with(payload)

      described_class.call(payload).join
    end

    context 'with exceptions processing payload' do
      let(:exception) { StandardError.new }

      before do
        expect(Rollbar).to receive(:process_from_async_handler).with(payload).and_raise(exception)
      end

      it 'doesnt raise any exception' do
        expect do
          described_class.call(payload).join
        end.not_to raise_exception(exception)
      end
    end
  end
end
