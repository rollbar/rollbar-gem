require 'spec_helper'
require 'rollbar/truncation/frames_strategy'

describe Rollbar::Truncation::MinBodyStrategy do
  describe '.call', :fixture => :payload do
    let(:message) { 'a' * 1_000 }

    context 'with trace key ' do
      let(:payload_fixture) { 'payloads/sample.trace.json' }
      let!(:frames) { payload['data']['body']['trace']['frames'].clone }

      before do
        payload['data']['body']['trace']['exception']['message'] = message
      end

      it 'truncates the exception message and frames array' do
        result = Rollbar::JSON.load(described_class.call(payload))

        trace = result['data']['body']['trace']
        expect(trace['frames'].count).to eq 2
        expect(trace['exception']['message']).to be_eql('a' * 255)
      end
    end

    context 'with trace_chain key ' do
      let(:payload_fixture) { 'payloads/sample.trace_chain.json' }
      let!(:frames1) { payload['data']['body']['trace_chain'][0]['frames'].clone }
      let!(:frames2) { payload['data']['body']['trace_chain'][1]['frames'].clone }

      before do
        payload['data']['body']['trace_chain'][0]['exception']['message'] = message
        payload['data']['body']['trace_chain'][1]['exception']['message'] = message
      end

      it 'truncates the exception message and frames array' do
        result = Rollbar::JSON.load(described_class.call(payload))

        traces = result['data']['body']['trace_chain']
        expect(traces[0]['frames'].count).to eq 2
        expect(traces[0]['exception']['message']).to be_eql('a' * 255)

        expect(traces[1]['frames'].count).to eq 2
        expect(traces[1]['exception']['message']).to be_eql('a' * 255)
      end
    end

    context 'with a message payload' do
      let(:payload_fixture) { 'payloads/message.json' }

      it "doesn't truncate anything and returns same payload" do
        result = Rollbar::JSON.load(described_class.call(payload))

        expect(result).to be_eql(payload)
      end
    end
  end
end
