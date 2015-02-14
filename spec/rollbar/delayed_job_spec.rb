require 'spec_helper'
require 'delayed_job'
require 'rollbar'
require 'rollbar/delayed_job'

describe Rollbar::Delayed, :reconfigure_notifier => true do
  class FailingJob
    class TestException < Exception; end

    def perform
      fail(TestException, 'failing')
    end
  end

  module DummyBackend
    class Job
      include Delayed::Backend::Base

      attr_accessor :handler, :attempts

      def initialize(options = {})
        @payload_object = options[:payload_object]
        @attempts = 0
      end
    end
  end

  let(:logger) { Rollbar.logger }

  before do
    Rollbar::Delayed.wrap_worker
    Delayed::Worker.delay_jobs = false
    Delayed::Worker.backend = DummyBackend::Job
  end

  let(:expected_args) do
    [kind_of(FailingJob::TestException), { :use_exception_level_filters => true}]
  end

  it 'sends the exception' do
    expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*expected_args)

    expect do
      Delayed::Job.enqueue(FailingJob.new)
    end.to raise_error(FailingJob::TestException)
  end
end
