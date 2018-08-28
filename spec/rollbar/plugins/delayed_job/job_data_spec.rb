require 'spec_helper'
require 'rollbar/plugins/delayed_job/job_data'
require 'delayed/backend/test'

# In delayed_job/lib/delayed/syck_ext.rb YAML.load_dj
# is broken cause it's defined as an instance method
# instead of module/class method. This is breaking
# the tests for ruby 1.8.7
if YAML.parser.class.name =~ /syck|yecht/i
  module YAML
    def self.load_dj(yaml)
      # See https://github.com/dtao/safe_yaml
      # When the method is there, we need to load our YAML like this...
      respond_to?(:unsafe_load) ? load(yaml, :safe => false) : load(yaml)
    end
  end
end

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
