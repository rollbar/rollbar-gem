require 'spec_helper'
require 'rollbar'
require 'delayed_job'
require 'delayed/backend/test'

Rollbar.plugins.load!

describe Rollbar::Delayed, :reconfigure_notifier => true do
  class FailingJob
    class TestException < RuntimeError; end

    def do_job_please!(_a, _b)
      _this = will_crash_again!
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

    it 'adds the job data' do
      payload = nil

      ::Rollbar::Item.any_instance.stub(:dump) do |item|
        payload = item.payload
        nil
      end

      FailingJob.new.delay.do_job_please!(:foo, :bar)

      expect(payload['data'][:request]["handler"]).to include({:args=>[:foo, :bar], :method_name=>:do_job_please!})
    end
  end

  context 'with failed deserialization' do
    let(:old_expected_args) do
      [/Delayed::DeserializationError/, { :use_exception_level_filters => true }]
    end
    let(:new_expected_args) do
      [instance_of(Delayed::DeserializationError), { :use_exception_level_filters => true }]
    end


    it 'sends the exception' do
      expect(Rollbar).to receive(:scope).with(kind_of(Hash)).and_call_original
      allow_any_instance_of(Delayed::Backend::Base).to receive(:payload_object).and_raise(Delayed::DeserializationError)
      if Delayed::Backend::Base.method_defined? :error
        expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*new_expected_args)
      else
        expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*old_expected_args)
      end

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
        if Delayed::Backend::Base.method_defined? :error
          expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*new_expected_args)
        else
          expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*old_expected_args)
        end

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
    subject(:call_skip_report) { described_class.skip_report?(job) }
    let(:configuration) { Rollbar.configuration }
    let(:threshold) { 5 }

    before do
      allow(configuration).to receive(:dj_threshold).and_return(threshold)
    end

    context 'with attempts > configuration.dj_threshold' do
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
          :job => { :payload_object => payload_object }
        )
      end

      it 'returns true' do
        expect(call_skip_report).to be(false)
      end
    end

    context 'with attempts < configuration.dj_threshold' do
      let(:job) { double(:attempts => 3) }

      it 'returns false' do
        expect(call_skip_report).to be(true)
      end
    end

    context 'with async_skip_report_handler set' do
      let(:job) { double(:attempts => 3) }
      let(:handler) { double('handler') }

      before do
        allow(configuration).to receive(:async_skip_report_handler).and_return(handler)
        allow(handler).to receive(:respond_to).with(:call).and_return(true)
      end

      it 'when handler.call returns false' do
        expect(handler).to receive(:call).with(job).and_return(false)
        expect(call_skip_report).to be(false)
      end

      it 'when handler.call returns true' do
        expect(handler).to receive(:call).with(job).and_return(true)
        expect(call_skip_report).to be(true)
      end
    end
  end
end
