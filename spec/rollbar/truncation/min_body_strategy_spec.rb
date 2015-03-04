require 'spec_helper'
require 'rollbar/truncation/min_body_strategy'

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
        result = MultiJson.load(described_class.call(payload))

        trace = result['data']['body']['trace']
        expect(trace['frames'].size).to eq(2)
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
        result = MultiJson.load(described_class.call(payload))

        traces = result['data']['body']['trace_chain']
        expect(traces[0]['frames'].size).to eq(2)
        expect(traces[0]['exception']['message']).to be_eql('a' * 255)

        expect(traces[1]['frames'].size).to eq(2)
        expect(traces[1]['exception']['message']).to be_eql('a' * 255)
      end
    end
  end
end
