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

describe Rollbar::Delayed::JobData, :reconfigure_notifier => true do
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

    context 'with a custom job object' do
      let(:custom_job_class) do
        Class.new do
          def self.name
            'MyCustomJob'
          end

          def initialize(user_id)
            @user_id = user_id
          end
        end
      end

      let(:job) { ::Delayed::Backend::Test::Job.new('attempts' => 1) }

      before do
        allow(job).to receive(:payload_object).and_return(custom_job_class.new(42))
      end

      it 'sends the job class and attributes instead of its #to_s' do
        expect(subject.to_hash['handler']).to eq(
          'class' => 'MyCustomJob',
          'attributes' => { 'user_id' => 42 }
        )
      end

      it 'scrubs the attributes matching scrub_fields' do
        Rollbar.configure { |config| config.scrub_fields |= [:user_id] }

        expect(subject.to_hash['handler']['attributes']['user_id']).to match(/\A\*+\z/)
      end
    end

    context 'with a job object that has circular references' do
      let(:job) { ::Delayed::Backend::Test::Job.new('attempts' => 1) }

      before do
        stub_const('CircularJob', Class.new { attr_accessor :parent })

        payload_object = CircularJob.new
        payload_object.parent = payload_object

        allow(job).to receive(:payload_object).and_return(payload_object)
      end

      it 'sends only the job class' do
        expect(subject.to_hash['handler']).to eq('class' => 'CircularJob')
      end
    end

    context 'with a job object whose as_json is not a Hash' do
      let(:job) { ::Delayed::Backend::Test::Job.new('attempts' => 1) }

      before do
        stub_const('StringJob', Class.new do
          def as_json(*)
            'string-job'
          end
        end)
        allow(job).to receive(:payload_object).and_return(StringJob.new)
      end

      it 'sends the as_json value as the attributes' do
        expect(subject.to_hash['handler']).to eq(
          'class' => 'StringJob',
          'attributes' => 'string-job'
        )
      end
    end

    context 'with a Struct job object' do
      let(:job) { ::Delayed::Backend::Test::Job.new('attempts' => 1) }

      before do
        stub_const('StructJob', Struct.new(:user_id))
        allow(job).to receive(:payload_object).and_return(StructJob.new(42))
      end

      it 'sends the struct members' do
        expect(subject.to_hash['handler']).to eq(
          'class' => 'StructJob',
          'attributes' => { 'user_id' => 42 }
        )
      end
    end

    context 'without ActiveSupport loaded' do
      let(:job) { ::Delayed::Backend::Test::Job.new('attempts' => 1) }

      before do
        allow(payload_object).to receive(:respond_to?).and_call_original
        allow(payload_object).to receive(:respond_to?).with(:as_json).and_return(false)
        allow(job).to receive(:payload_object).and_return(payload_object)
      end

      context 'with a Struct job object' do
        let(:payload_object) do
          stub_const('StructJob', Struct.new(:user_id))
          StructJob.new(42)
        end

        it 'sends the struct members with string keys' do
          expect(subject.to_hash['handler']).to eq(
            'class' => 'StructJob',
            'attributes' => { 'user_id' => 42 }
          )
        end
      end

      context 'with a custom job object' do
        let(:payload_object) do
          stub_const('IvarJob', Class.new do
            def initialize(user_id, password)
              @user_id = user_id
              @password = password
            end
          end)
          IvarJob.new(42, 'hunter2')
        end

        it 'sends its instance variables, scrubbed' do
          handler = subject.to_hash['handler']

          expect(handler['class']).to eq('IvarJob')
          expect(handler['attributes']['user_id']).to eq(42)
          expect(handler['attributes']['password']).to match(/\A\*+\z/)
        end
      end
    end

    context 'with an ActiveJob job enqueued through the delayed_job adapter' do
      let(:job_data) do
        {
          'job_class' => 'MyActiveJob',
          'job_id' => 'abc',
          'arguments' => [42, 'secret']
        }
      end
      let(:wrapper) { double(:job_data => job_data) }
      let(:job) { ::Delayed::Backend::Test::Job.new('attempts' => 1) }

      before do
        stub_const('MyActiveJob', Class.new)
        allow(job).to receive(:payload_object).and_return(wrapper)
      end

      it 'sends the ActiveJob job data' do
        expect(subject.to_hash['handler']).to eq(job_data)
      end

      context 'when the job has log_arguments disabled' do
        before do
          MyActiveJob.define_singleton_method(:log_arguments?) { false }
        end

        it 'scrubs the arguments' do
          handler = subject.to_hash['handler']

          expect(handler['job_class']).to eq('MyActiveJob')
          expect(handler['arguments']).to all(match(/\A\*+\z/))
        end
      end
    end
  end
end
