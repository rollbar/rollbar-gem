require 'spec_helper'

require 'active_support/rescuable'

describe Rollbar::ActiveJob do
  class TestJob
    # To mix in rescue_from
    include ActiveSupport::Rescuable
    include Rollbar::ActiveJob

    attr_reader :job_id

    def perform(exception, job_id)
      @job_id = job_id
      # ActiveJob calls rescue_with_handler when a job raises an exception
      rescue_with_handler(exception) || raise(exception)
    end
  end

  before { reconfigure_notifier }

  let(:exception) { StandardError.new('oh no') }
  let(:job_id) { "123" }

  it "reports the error to Rollbar" do
    expected_params = { :job => "TestJob", :job_id => job_id }
    expect(Rollbar).to receive(:error).with(exception, expected_params)
    TestJob.new.perform(exception, job_id) rescue nil
  end

  it "reraises the error so the job backend can handle the failure and retry" do
    expect { TestJob.new.perform(exception, job_id) }.to raise_error exception
  end
end
