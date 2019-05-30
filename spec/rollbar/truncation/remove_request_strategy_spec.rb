require 'spec_helper'
require 'rollbar/truncation/remove_request_strategy'

describe Rollbar::Truncation::RemoveRequestStrategy do
  describe '.call' do
    let(:body) { { 'foo' => 'bar' } }
    let(:request) { { 'bar' => 'baz' } }
    let(:payload) do
      {
        'data' => {
          'body' => body,
          'request' => request
        }
      }
    end

    it 'should truncate the request in the payload' do
      result = Rollbar::JSON.load(described_class.call(Rollbar::Util.deep_copy(payload)))

      expect(result['data']['body']).to be_eql(body)
      expect(result['data']['request']).to be_nil
    end
  end
end
