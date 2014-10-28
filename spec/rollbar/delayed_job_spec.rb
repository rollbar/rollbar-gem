require 'spec_helper'
require 'delayed_job'
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

  it 'sends the exception' do
    expect do
      Delayed::Job.enqueue(FailingJob.new)
    end.to raise_error(FailingJob::TestException)

    last_report = Rollbar.last_report
    expect(last_report[:request]).to be_kind_of(DummyBackend::Job)
  end
end
