require 'spec_helper'
require 'rollbar/truncation'

describe Rollbar::Truncation do
  describe '.truncate' do
    let(:payload) { {} }

    context 'if truncation is not needed' do
      it 'only calls RawStrategy is truncation is not needed' do
        allow(described_class).to receive(:truncate?).and_return(false)
        expect(Rollbar::Truncation::RawStrategy).to receive(:call).with(payload)

        Rollbar::Truncation.truncate(payload)
      end
    end

    context 'if truncation is needed' do
      it 'calls the next strategy, FramesStrategy' do
        allow(described_class).to receive(:truncate?).and_return(true, false)
        expect(Rollbar::Truncation::RawStrategy).to receive(:call).with(payload)
        expect(Rollbar::Truncation::FramesStrategy).to receive(:call).with(payload)

        Rollbar::Truncation.truncate(payload)
      end
    end
  end
end
