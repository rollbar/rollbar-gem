require 'spec_helper'

require 'rollbar/plugins/delayed_job/job_data'
require 'delayed/backend/test'

describe Rollbar::Delayed::JobData do
  describe '#to_hash' do
    let(:handler) { { 'foo' => 'bar' } }

    let(:attrs) do
      {
        'id' => 1,
        'priority' => 0,
        'attempts' => 1,
        'handler' => handler.to_yaml
      }
    end

    let(:job) do
      ::Delayed::Backend::Test::Job.new(attrs)
    end

    subject { described_class.new(job) }

    it 'returns the correct job data' do
      expected_result = attrs.dup
      expected_result.delete('id')
      expected_result['handler'] = handler

      result = subject.to_hash

      expect(result).to be_eql(expected_result)
    end
  end
end
