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

  # Runs a mail delivery job with the arguments `deliver_later` would enqueue.
  # Unlike perform_enqueued_jobs, this lets an error the job re-raises reach
  # the example instead of wrapping it in Minitest::UnexpectedError.
  def perform_delivery(job_class, mailer, *args)
    mail_delivery_job = defined?(ActionMailer::MailDeliveryJob) &&
                        job_class <= ActionMailer::MailDeliveryJob
    if mail_delivery_job
      job_class.perform_now(mailer, 'test_email', 'deliver_now', :args => args)
    else
      job_class.perform_now(mailer, 'test_email', 'deliver_now', *args)
    end
  end

  # Expects `delivery_job_class`, the ActionMailer delivery job under test.
  shared_examples 'a mailer delivery job' do # rubocop:disable Metrics/BlockLength
    before do
      stub_const('DiscardedMailerError', Class.new(StandardError))
      stub_const('RescuedByJobMailerError', Class.new(StandardError))
      stub_const('RescuedByMailerError', Class.new(StandardError))

      stub_const('HandlingDeliveryJob', Class.new(delivery_job_class) do
        discard_on DiscardedMailerError
        rescue_from(RescuedByJobMailerError) { |_e| nil }
      end)

      stub_const('HandlingMailer', Class.new(ActionMailer::Base) do
        self.delivery_job = HandlingDeliveryJob
        rescue_from(RescuedByMailerError) { |_e| nil }

        def test_email(error_class)
          raise error_class.constantize, 'handled'
        end
      end)
    end

    %w[DiscardedMailerError RescuedByJobMailerError RescuedByMailerError].each do |name|
      it "doesn't report #{name}" do
        expect(Rollbar).not_to receive(:error)

        expect do
          perform_enqueued_jobs { HandlingMailer.test_email(name).deliver_later }
        end.not_to raise_error
      end
    end

    it 'reports errors the delivery job subclass does not handle' do
      expected_params = {
        :job => 'HandlingDeliveryJob',
        :use_exception_level_filters => true
      }
      expect(Rollbar).to receive(:error).once.with(kind_of(ArgumentError),
                                                   hash_including(expected_params))

      expect do
        perform_delivery(HandlingDeliveryJob, 'HandlingMailer', 'ArgumentError')
      end.to raise_error(ArgumentError, 'handled')
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

  context 'using ActionMailer::MailDeliveryJob', :if => Gem::Version.new(Rails.version) >= Gem::Version.new('6.0') do
    class ParentMailer < ActionMailer::Base; end

    class TestMailer2 < ParentMailer
      def test_email(*_arguments)
        error = StandardError.new('oh no')
        raise(error)
      end
    end

    include ActiveJob::TestHelper if defined?(ActiveJob::TestHelper)

    it_behaves_like 'an ActiveMailer plugin'

    it 'reports the error to Rollbar' do
      expected_params = {
        :job => 'ActionMailer::MailDeliveryJob',
        :use_exception_level_filters => true
      }
      expect(Rollbar).to receive(:error).once.with(kind_of(StandardError),
                                                   hash_including(expected_params))

      perform_enqueued_jobs do
        begin
          TestMailer2.test_email(argument).deliver_later
        rescue StandardError
          nil
        end
      end
    end

    it 'reraises unhandled mailer errors' do
      expect do
        ActionMailer::MailDeliveryJob.perform_now('TestMailer2', 'test_email',
                                                  'deliver_now', :args => [argument])
      end.to raise_error(StandardError, 'oh no')
    end

    it 'reports once when the mailer includes Rollbar::ActiveJob' do
      stub_const('IncludingMailer', Class.new(ActionMailer::Base) do
        include Rollbar::ActiveJob

        def test_email(*_arguments)
          raise StandardError, 'oh no'
        end
      end)

      expect(Rollbar).to receive(:error).once.with(
        kind_of(StandardError), hash_including(:job => 'ActionMailer::MailDeliveryJob')
      )

      expect do
        perform_delivery(ActionMailer::MailDeliveryJob, 'IncludingMailer', argument)
      end.to raise_error(StandardError, 'oh no')
    end

    it 'reports ActiveJob::DeserializationError to Rollbar' do
      user = User.create!(:email => 'deleted@example.com')

      ActiveJob::Base.queue_adapter = :test
      job = TestMailer2.test_email(user).deliver_later
      user.destroy

      expected_params = {
        :job => 'ActionMailer::MailDeliveryJob',
        :use_exception_level_filters => true
      }
      expect(Rollbar).to receive(:error)
        .once
        .with(kind_of(ActiveJob::DeserializationError), hash_including(expected_params))

      # Run the job the way queue adapters do. On older Rails, perform_enqueued_jobs
      # deserializes arguments before calling perform_now, bypassing the wrapper.
      expect do
        ActiveJob::Base.execute(job.serialize)
      end.to raise_error(ActiveJob::DeserializationError)
    end

    it_behaves_like 'a mailer delivery job' do
      let(:delivery_job_class) { ActionMailer::MailDeliveryJob }
    end
  end

  # Rails 6.x ships both job classes. Apps that haven't switched
  # `delivery_job` to MailDeliveryJob still deliver through DeliveryJob.
  context 'using the legacy ActionMailer::DeliveryJob on Rails 6.x',
          :if => Gem::Version.new(Rails.version) >= Gem::Version.new('6.0') &&
                 Gem::Version.new(Rails.version) < Gem::Version.new('7.0') do
    include ActiveJob::TestHelper if defined?(ActiveJob::TestHelper)

    # DeliveryJob logs a deprecation warning every time it runs on Rails 6.x.
    around { |example| ActiveSupport::Deprecation.silence { example.run } }

    it 'reports the error to Rollbar' do
      stub_const('LegacyMailer', Class.new(ActionMailer::Base) do
        self.delivery_job = ActionMailer::DeliveryJob

        def test_email(*_arguments)
          raise StandardError, 'oh no'
        end
      end)

      expected_params = {
        :job => 'ActionMailer::DeliveryJob',
        :use_exception_level_filters => true,
        :arguments => ['LegacyMailer', 'test_email', 'deliver_now', 12]
      }
      expect(Rollbar).to receive(:error).once.with(kind_of(StandardError),
                                                   hash_including(expected_params))

      expect do
        perform_delivery(ActionMailer::DeliveryJob, 'LegacyMailer', argument)
      end.to raise_error(StandardError, 'oh no')
    end

    it_behaves_like 'a mailer delivery job' do
      let(:delivery_job_class) { ActionMailer::DeliveryJob }
    end
  end
end
