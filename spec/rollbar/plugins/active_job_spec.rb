require 'spec_helper'

require 'active_support/rescuable'

describe Rollbar::ActiveJob do
  class TestJob
    # To mix in rescue_from
    include ActiveSupport::Rescuable
    include Rollbar::ActiveJob

    attr_reader :job_id
    attr_accessor :arguments

    def initialize(*arguments)
      @arguments = arguments
    end

    def perform(exception, job_id)
      @job_id = job_id
      # ActiveJob calls rescue_with_handler when a job raises an exception
      rescue_with_handler(exception) || raise(exception)
    end
  end

  before { reconfigure_notifier }

  let(:exception) { StandardError.new('oh no') }
  let(:job_id) { '123' }
  let(:argument) { 12 }

  it 'reports the error to Rollbar' do
    expected_params = {
      :job => 'TestJob',
      :job_id => job_id,
      :use_exception_level_filters => true,
      :arguments => [argument]
    }
    expect(Rollbar).to receive(:error).with(exception, expected_params)
    TestJob.new(argument).perform(exception, job_id) rescue nil # rubocop:disable Style/RescueModifier
  end

  it 'reraises the error so the job backend can handle the failure and retry' do
    expect { TestJob.new(argument).perform(exception, job_id) }.to raise_error exception
  end

  context 'using ActionMailer::DeliveryJob', :if => defined?(ActionMailer::DeliveryJob) do
    include ActiveJob::TestHelper if defined?(ActiveJob::TestHelper) # rubocop:disable Style/MixinUsage

    class TestMailer < ActionMailer::Base
      attr_accessor :arguments

      def test_email(*_arguments)
        error = StandardError.new('oh no')
        raise(error)
      end
    end

    it 'job is created' do
      ActiveJob::Base.queue_adapter = :test
      expect do
        TestMailer.test_email(argument).deliver_later
      end.to have_enqueued_job.on_queue('mailers')
    end

    it 'reports the error to Rollbar' do
      expected_params = {
        :job => 'ActionMailer::DeliveryJob',
        :use_exception_level_filters => true,
        :arguments => ['TestMailer', 'test_email', 'deliver_now', 12]
      }
      expect(Rollbar).to receive(:error).with(kind_of(StandardError), hash_including(expected_params))
      perform_enqueued_jobs do
        TestMailer.test_email(argument).deliver_later rescue nil # rubocop:disable Style/RescueModifier
      end
    end
  end
end
