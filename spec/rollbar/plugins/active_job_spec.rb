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

    context 'when the error is handled' do
      before do
        stub_const('DiscardedMailerError', Class.new(StandardError))
        stub_const('RescuedByJobMailerError', Class.new(StandardError))
        stub_const('RescuedByMailerError', Class.new(StandardError))

        stub_const('HandlingDeliveryJob', Class.new(ActionMailer::MailDeliveryJob) do
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
          HandlingDeliveryJob.perform_now('HandlingMailer', 'test_email', 'deliver_now',
                                          :args => ['ArgumentError'])
        end.to raise_error(ArgumentError)
      end
    end
  end
end
