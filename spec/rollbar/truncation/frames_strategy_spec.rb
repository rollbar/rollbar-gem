require 'spec_helper'
require 'rollbar/truncation/frames_strategy'

describe Rollbar::Truncation::FramesStrategy do
  def expand_frames(frames)
    frames * (1 + 300 / frames.count)
  end

  describe '.call', :fixture => :payload do
    context 'with trace key' do
      let(:payload_fixture) { 'payloads/sample.trace.json' }
      let(:frames) { payload['data']['body']['trace']['frames'].clone }

      before do
        payload['data']['body']['trace']['frames'] = expand_frames(frames)
      end

      it 'returns a new payload with 100 frames' do
        result = Rollbar::JSON.load(described_class.call(payload))

        new_frames = result['data']['body']['trace']['frames']

        expect(new_frames.count).to be_eql(100)
        expect(new_frames.first).to be_eql(frames.first)
        expect(new_frames.last).to be_eql(frames.last)
      end
    end

    context 'with trace_chain key' do
      let(:payload_fixture) { 'payloads/sample.trace_chain.json' }

      let(:frames1) { payload['data']['body']['trace_chain'][0]['frames'].clone }
      let(:frames2) { payload['data']['body']['trace_chain'][1]['frames'].clone }

      before do
        payload['data']['body']['trace_chain'][0]['frames'] = expand_frames(frames1)
        payload['data']['body']['trace_chain'][1]['frames'] = expand_frames(frames2)
      end

      it 'returns a new payload with 100 frames for each chain item' do
        result = Rollbar::JSON.load(described_class.call(payload))

        new_frames1 = result['data']['body']['trace_chain'][0]['frames']
        new_frames2 = result['data']['body']['trace_chain'][1]['frames']

        expect(new_frames1.count).to be_eql(100)
        expect(new_frames1.first).to be_eql(frames1.first)
        expect(new_frames1.last).to be_eql(frames1.last)

        expect(new_frames2.count).to be_eql(100)
        expect(new_frames2.first).to be_eql(frames2.first)
        expect(new_frames2.last).to be_eql(frames2.last)
      end
    end

    context 'without trace or trace_chain', :fixture => :payload do
      let(:payload_fixture) { 'payloads/sample.trace.json' }

      before do
        payload['data']['body'].delete('trace')
      end

      it 'returns the original payload' do
        result = Rollbar::JSON.load(described_class.call(payload))

        expect(result).to be_eql(payload)
      end
    end
  end
end
