require 'spec_helper'
require 'rollbar'
require 'delayed_job'
require 'delayed/backend/test'

Rollbar.plugins.load!

describe Rollbar::Delayed, :reconfigure_notifier => true do
  class FailingJob
    class TestException < Exception; end

    def do_job_please!(a, b)
      this = will_crash_again!
    end
  end

  before do
    Delayed::Backend::Test.prepare_worker

    Delayed::Worker.backend = :test
    Delayed::Backend::Test::Job.delete_all
  end

  let(:expected_args) do
    [kind_of(NoMethodError), { :use_exception_level_filters => true }]
  end

  context 'with delayed method without arguments failing' do
    it 'sends the exception' do
      expect(Rollbar).to receive(:scope).with(kind_of(Hash)).and_call_original
      expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*expected_args)

      FailingJob.new.delay.do_job_please!(:foo, :bar)
    end
  end

  context 'with failed deserialization' do
    let(:expected_args) do
      [/Delayed::DeserializationError/, {:use_exception_level_filters=>true}]
    end

    it 'sends the exception' do
      expect(Rollbar).to receive(:scope).with(kind_of(Hash)).and_call_original
      allow_any_instance_of(Delayed::Backend::Base).to receive(:payload_object).and_raise(Delayed::DeserializationError)
      expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*expected_args)

      FailingJob.new.delay.do_job_please!(:foo, :bar)
    end
    
    context 'with dj_threshold > 0' do
      before do
        Rollbar.configure do |config|
          config.dj_threshold = 1
        end
      end
      
      it 'sends the exception' do
        expect(Rollbar).to receive(:scope).with(kind_of(Hash)).and_call_original
        allow_any_instance_of(Delayed::Backend::Base).to receive(:payload_object).and_raise(Delayed::DeserializationError)
        expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*expected_args)
  
        FailingJob.new.delay.do_job_please!(:foo, :bar)
      end
    end
  end

  describe '.build_job_data' do
    let(:job) { double(:payload_object => {}) }

    context 'if report_dj_data is disabled' do
      before do
        allow(Rollbar.configuration).to receive(:report_dj_data).and_return(false)
      end

      it 'returns nil' do
        expect(described_class.build_job_data(job)).to be_nil
      end
    end

    context 'with report_dj_data enabled' do
      before do
        allow(Rollbar.configuration).to receive(:report_dj_data).and_return(true)
      end

      it 'returns a hash' do
        result = described_class.build_job_data(job)
        expect(result).to be_kind_of(Hash)
      end
    end
  end

  describe '.skip_report' do
    let(:configuration) { Rollbar.configuration }
    let(:threshold) { 5 }
    let(:only_report_failures) { false }

    before do
      allow(configuration).to receive(:dj_threshold).and_return(threshold)
      allow(configuration).to receive(:dj_only_report_failures).and_return(only_report_failures)
    end

    context 'with attempts > configuration.dj_threshold' do
      let(:failed_at) { nil }
      let(:object) do
        double(:to_s => 'foo')
      end
      let(:payload_object) do
        double(:method_name => 'foo',
               :args => [1, 2],
               :object => object)
      end
      let(:job) do
        double(
          :attempts => 6,
          :failed_at => failed_at,
          :job => { :payload_object => payload_object }
        )
      end

      it 'returns false' do
        expect(described_class.skip_report?(job)).to be(false)
      end

      context 'with configuration.only_report_failures = true' do
        context 'and the job is failed' do
          let(:failed_at) { Time.now }

          it 'returns false' do
            expect(described_class.skip_report?(job)).to be(false)
          end
        end
      end
    end

    context 'with attempts < configuration.dj_threshold' do
      let(:job) { double(:attempts => 3) }

      it 'returns true' do
        expect(described_class.skip_report?(job)).to be(true)
      end
    end
  end
end
