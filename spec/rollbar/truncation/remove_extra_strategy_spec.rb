require 'spec_helper'
require 'rollbar/truncation/remove_extra_strategy'

describe Rollbar::Truncation::RemoveExtraStrategy do
  describe '.call' do
    let(:extra) { { 'bar' => 'baz' } }
    let(:request) { { 'baz' => 'fizz' } }

    context 'with message payload type' do
      let(:message_body) { { 'foo' => 'bar' } }

      let(:payload) do
        {
          'data' => {
            'body' => {
              'message' => {
                'body' => message_body,
                'extra' => extra
              }
            },
            'request' => request
          }
        }
      end

      it 'should truncate the extra data in the payload' do
        result = Rollbar::JSON.load(described_class.call(Rollbar::Util.deep_copy(payload)))

        expect(result['data']['body']['message']['extra']).to be_nil
        expect(result['data']['body']['message']['body']).to be_eql(message_body)
        expect(result['data']['request']).to be_eql(request)
      end
    end

    context 'with trace payload type' do
      let(:trace_frames) { { 'foo' => 'bar' } }

      let(:payload) do
        {
          'data' => {
            'body' => {
              'trace' => {
                'frames' => trace_frames,
                'extra' => extra
              }
            },
            'request' => request
          }
        }
      end

      it 'should truncate the extra data in the payload' do
        result = Rollbar::JSON.load(described_class.call(Rollbar::Util.deep_copy(payload)))

        expect(result['data']['body']['trace']['extra']).to be_nil
        expect(result['data']['body']['trace']['frames']).to be_eql(trace_frames)
        expect(result['data']['request']).to be_eql(request)
      end
    end

    context 'with trace_chain payload type' do
      let(:trace_frames) { { 'foo' => 'bar' } }

      let(:payload) do
        {
          'data' => {
            'body' => {
              'trace_chain' => [{
                'frames' => trace_frames,
                'extra' => extra
              }]
            },
            'request' => request
          }
        }
      end

      it 'should truncate the extra data in the payload' do
        result = Rollbar::JSON.load(described_class.call(Rollbar::Util.deep_copy(payload)))

        expect(result['data']['body']['trace_chain'][0]['extra']).to be_nil
        expect(result['data']['body']['trace_chain'][0]['frames']).to be_eql(trace_frames)
        expect(result['data']['request']).to be_eql(request)
      end
    end
  end
end
