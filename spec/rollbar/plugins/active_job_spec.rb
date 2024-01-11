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
  end
end
