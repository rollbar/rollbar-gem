require 'spec_helper'
require 'rollbar/truncation/remove_any_key_strategy'

describe Rollbar::Truncation::RemoveAnyKeyStrategy do
  describe '.call' do
    let(:exception_class) { 'ExceptionClass' }
    let(:exception_message) { 'Exception message' }
    let(:body) do
      {
        'trace' => {
          'exception' => {
            'class' => exception_class,
            'message' => exception_message
          }
        },
        'foo' => 'bar' * 999
      }
    end
    let(:request) { { 'bar' => 'baz' } }
    let(:payload) do
      {
        'data' => {
          'body' => body,
          'request' => request,
          'notifier' => {}
        },
        'unknown_root_key' => { 'foo' => 'bar' }
      }
    end
    let(:truncation_message) do
      {
        'message' => {
          'body' => 'Payload keys removed due to oversized payload. See diagnostic key'
        }
      }
    end
    let(:diagnostic) do
      {
        'diagnostic' => {
          'truncation' => {
            'body' => 'key removed, size: 3086 bytes',
            'root' => {
              'unknown_root_key' => 'unknown root key removed, size: 13 bytes'
            }
          }
        }
      }
    end

    it 'should remove unknown and oversized keys in the payload' do
      result = Rollbar::JSON.load(described_class.call(Rollbar::Util.deep_copy(payload)))

      original_payload_size = Rollbar::Truncation::MAX_PAYLOAD_SIZE
      Rollbar::Truncation::MAX_PAYLOAD_SIZE = 200

      expect(result['data']['body']).to be_eql(truncation_message)
      expect(result['data']['request']).to be_eql(request)
      expect(result['data']['title']).to be_eql([exception_class, exception_message].join(': '))
      expect(result['unknown_root_key']).to be_nil
      expect(result['data']['notifier']).to be_eql(diagnostic)

      Rollbar::Truncation::MAX_PAYLOAD_SIZE = original_payload_size
    end
  end
end
