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
  let(:expected_params) do
    {
      :job => 'TestJob',
      :job_id => job_id,
      :use_exception_level_filters => true,
      :arguments => [argument]
    }
  end

  shared_examples 'an ActiveMailer plugin' do
    it 'reraises the error so the job backend can handle the failure and retry' do
      expect do
        TestJob.new(argument).perform(exception, job_id)
      end.to raise_error exception
    end

    it 'job is created' do
      ActiveJob::Base.queue_adapter = :test
      expect do
        TestMailer.test_email(argument).deliver_later
      end.to have_enqueued_job.on_queue('mailers')
    end

    context 'disabled in config' do
      subject { Rollbar.plugins.get('active_job') }
      before do
        subject.unload!

        # Configur will load all plugins after applying the config.
        Rollbar.configure { |c| c.disable_action_mailer_monkey_patch = true }
      end

      it "isn't loaded" do
        expect(subject.loaded).to eq(false)
      end
    end
  end

  context 'using ActionMailer::DeliveryJob', :if => Gem::Version.new(Rails.version) < Gem::Version.new('6.0') do
    class TestMailer < ActionMailer::Base
      attr_accessor :arguments

      def test_email(*_arguments)
        error = StandardError.new('oh no')
        raise(error)
      end
    end

    include ActiveJob::TestHelper if defined?(ActiveJob::TestHelper)

    it_behaves_like 'an ActiveMailer plugin'

    it 'reports the job error to Rollbar' do
      expect(Rollbar).to receive(:error).with(exception, expected_params)
      begin
        TestJob.new(argument).perform(exception, job_id)
      rescue StandardError
        nil
      end
    end

    it 'reports the mailer error to Rollbar' do
      expected_params = {
        :job => 'ActionMailer::DeliveryJob',
        :use_exception_level_filters => true,
        :arguments => ['TestMailer', 'test_email', 'deliver_now', 12]
      }
      expect(Rollbar).to receive(:error).with(kind_of(StandardError),
                                              hash_including(expected_params))
      perform_enqueued_jobs do
        begin
          TestMailer.test_email(argument).deliver_later
        rescue StandardError
          nil
        end
      end
    end

    it 'scrubs all arguments if job has `log_arguments` disabled' do
      allow(TestJob).to receive(:log_arguments?).and_return(false)

      expected_params[:job_id] = job_id
      expected_params[:arguments] = ['******', '******', '******']
      expect(Rollbar).to receive(:error).with(exception, expected_params)
      begin
        TestJob.new(1, 2, 3).perform(exception, job_id)
      rescue StandardError
        nil
      end
    end

    it 'scrubs job arguments hash' do
      Rollbar.configure do |config|
        config.scrub_fields |= ['user_id']
      end

      perform_enqueued_jobs do
        begin
          TestMailer.test_email(:user_id => '15').deliver_later
        rescue StandardError
          nil
        end
      end
      Rollbar.last_report[:body][:trace][:extra][:arguments][3][:user_id]
             .should match(/^*+$/)
    end

    it 'scrubs job arguments HashWithIndifferentAccess' do
      Rollbar.configure do |config|
        config.scrub_fields |= ['user_id']
      end

      params = ActiveSupport::HashWithIndifferentAccess.new
      params['user_id'] = '15'

      perform_enqueued_jobs do
        begin
          TestMailer.test_email(params).deliver_later
        rescue StandardError
          nil
        end
      end
      Rollbar.last_report[:body][:trace][:extra][:arguments][3]['user_id']
             .should match(/^*+$/)
    end
  end

  # retry_on and discard_on were added in Rails 5.1. A plain `if` rather than
  # `:if` metadata, because the job classes below are defined either way.
  if Gem::Version.new(Rails.version) >= Gem::Version.new('5.1')
    context 'with retry_on and discard_on (#1183)' do
      module RetrySpecJob
        def self.performed
          @performed ||= []
        end

        def perform(failures)
          RetrySpecJob.performed << executions
          raise StandardError, "attempt #{executions} failed" if executions <= failures
        end
      end

      class IncludeThenRetryOnJob < ActiveJob::Base
        include Rollbar::ActiveJob
        retry_on StandardError, :wait => 0, :attempts => 3
        include RetrySpecJob
      end

      class RetryOnThenIncludeJob < ActiveJob::Base
        retry_on StandardError, :wait => 0, :attempts => 3
        include Rollbar::ActiveJob
        include RetrySpecJob
      end

      class IncludeThenDiscardOnJob < ActiveJob::Base
        include Rollbar::ActiveJob
        discard_on StandardError
        include RetrySpecJob
      end

      class DiscardOnThenIncludeJob < ActiveJob::Base
        discard_on StandardError
        include Rollbar::ActiveJob
        include RetrySpecJob
      end

      class RollbarParentJob < ActiveJob::Base
        include Rollbar::ActiveJob
      end

      class RollbarChildJob < RollbarParentJob
        include Rollbar::ActiveJob
        include RetrySpecJob
      end

      include ActiveJob::TestHelper if defined?(ActiveJob::TestHelper)

      before do
        ActiveJob::Base.queue_adapter = :test
        RetrySpecJob.performed.clear
      end

      # Returns the error that escaped the job, if any. The test adapter runs each
      # retry inside the previous attempt, so the final error is re-raised through
      # every earlier attempt's perform_now. It's rescued inside the block because
      # perform_enqueued_jobs can't log errors that escape it outside a TestCase.
      def run_job(job_class, failures)
        error = nil
        perform_enqueued_jobs do
          begin
            job_class.perform_later(failures)
          rescue StandardError => e
            error = e
          end
        end
        error
      end

      [IncludeThenRetryOnJob, RetryOnThenIncludeJob].each do |job_class|
        context "with #{job_class}" do
          it 'retries, then reports the final failure once' do
            expect(Rollbar).to receive(:error).once.with(
              having_attributes(:message => 'attempt 3 failed'),
              hash_including(:job => job_class.name, :job_id => kind_of(String),
                             :arguments => [99], :use_exception_level_filters => true)
            )

            expect(run_job(job_class, 99).message).to eq('attempt 3 failed')
            expect(RetrySpecJob.performed).to eq([1, 2, 3])
          end

          it "doesn't report an attempt that retry_on reschedules" do
            expect(Rollbar).not_to receive(:error)

            job_class.new(99).perform_now

            expect(RetrySpecJob.performed).to eq([1])
            expect(enqueued_jobs.size).to eq(1)
          end

          it "doesn't report a job that succeeds on retry" do
            expect(Rollbar).not_to receive(:error)

            expect(run_job(job_class, 1)).to be_nil
            expect(RetrySpecJob.performed).to eq([1, 2])
          end
        end
      end

      [IncludeThenDiscardOnJob, DiscardOnThenIncludeJob].each do |job_class|
        it "doesn't report an error discarded by discard_on in #{job_class}" do
          expect(Rollbar).not_to receive(:error)

          expect { job_class.new(99).perform_now }.not_to raise_error
        end
      end

      it 'reports once when included in both a job and its parent' do
        expect(Rollbar).to receive(:error).once

        expect { RollbarChildJob.new(99).perform_now }.to raise_error(StandardError)
      end

      it 'scrubs arguments if the job has `log_arguments` disabled',
         :if => IncludeThenRetryOnJob.respond_to?(:log_arguments?) do
        allow(IncludeThenRetryOnJob).to receive(:log_arguments?).and_return(false)

        expect(Rollbar).to receive(:error)
          .with(kind_of(StandardError), hash_including(:arguments => ['******']))

        expect(run_job(IncludeThenRetryOnJob, 99)).to be_a(StandardError)
      end

      context 'with the Rails error subscriber enabled',
              :if => ::Rails.gem_version >= ::Gem::Version.new('7.1.0') do
        before do
          Rollbar.configure { |config| config.enable_rails_error_subscriber = true }
        end

        after do
          Rollbar.configure { |config| config.enable_rails_error_subscriber = false }
        end

        # The Rails executor reports errors that escape the job to the error
        # subscriber, after the plugin has already reported them.
        [IncludeThenRetryOnJob, RetryOnThenIncludeJob].each do |job_class|
          it "reports the final failure of #{job_class} once" do
            expect(Rollbar).to receive(:error).once
            expect(Rollbar).not_to receive(:log)

            expect(run_job(job_class, 99).message).to eq('attempt 3 failed')
          end
        end
      end
    end
  end

  context 'using ActionMailer::MailDeliveryJob', :if => Gem::Version.new(Rails.version) >= Gem::Version.new('6.0') do
    class ParentMailer < ActionMailer::Base; end

    class TestMailer2 < ParentMailer
      def test_email(*_arguments)
        error = StandardError.new('oh no')
        raise(error)
      end
    end

    include ActiveJob::TestHelper if defined?(ActiveJob::TestHelper)

    let(:expected_params) do
      {
        :job => 'TestJob',
        :use_exception_level_filters => true,
        :action => 'test_email'
      }
    end

    it_behaves_like 'an ActiveMailer plugin'

    it 'reports the error to Rollbar' do
      expected_params.delete(:job)

      expect(Rollbar).to receive(:error).with(kind_of(StandardError),
                                              hash_including(expected_params))

      perform_enqueued_jobs do
        begin
          TestMailer2.test_email(argument).deliver_later
        rescue StandardError => e
          nil
        end
      end
    end

    it 'reports the error only once' do
      expect(Rollbar).to receive(:error).once

      perform_enqueued_jobs do
        begin
          TestMailer2.test_email(argument).deliver_later
        rescue StandardError
          nil
        end
      end
    end

    it 'reports ActiveJob::DeserializationError to Rollbar' do
      user = User.create!(:email => 'deleted@example.com')

      ActiveJob::Base.queue_adapter = :test
      job = TestMailer2.test_email(user).deliver_later
      user.destroy

      expect(Rollbar).to receive(:error)
        .once
        .with(kind_of(ActiveJob::DeserializationError),
              hash_including(:job => 'TestMailer2', :use_exception_level_filters => true))

      # Run the job the way queue adapters do. On older Rails, perform_enqueued_jobs
      # deserializes arguments before the job runs, bypassing rescue_from.
      expect do
        ActiveJob::Base.execute(job.serialize)
      end.to raise_error(ActiveJob::DeserializationError)
    end

    # ActionMailer::MailDeliveryJob was added in Rails 6. A plain `if`, like the
    # retry_on context, because the outer `:if` skips the examples but not the
    # class definitions below.
    if defined?(ActionMailer::MailDeliveryJob)
      context 'when the delivery job also includes Rollbar::ActiveJob' do
        class RollbarMailDeliveryJob < ActionMailer::MailDeliveryJob
          include Rollbar::ActiveJob
        end

        class RollbarDeliveryMailer < TestMailer2
          self.delivery_job = RollbarMailDeliveryJob
        end

        it 'reports ActiveJob::DeserializationError only once' do
          user = User.create!(:email => 'deleted@example.com')

          ActiveJob::Base.queue_adapter = :test
          job = RollbarDeliveryMailer.test_email(user).deliver_later
          user.destroy

          expect(Rollbar).to receive(:error)
            .once
            .with(kind_of(ActiveJob::DeserializationError),
                  hash_including(:job => 'RollbarDeliveryMailer'))

          expect do
            ActiveJob::Base.execute(job.serialize)
          end.to raise_error(ActiveJob::DeserializationError)
        end
      end
    end
  end
end
