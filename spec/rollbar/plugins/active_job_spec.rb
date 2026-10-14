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

  context 'with an ActiveJob::Base job' do
    class ScopedTestJob < ActiveJob::Base
      include Rollbar::ActiveJob

      cattr_accessor :scope_during_perform

      def perform(fail)
        self.class.scope_during_perform = Rollbar.scope_object.dup
        raise StandardError, 'oh no' if fail
      end
    end

    before do
      Rollbar.scope!(:person => { :id => 1 }, :request => { :url => '/users/1' })
    end

    after { Rollbar.reset_notifier! }

    it 'performs the job with a clean scope' do
      ScopedTestJob.perform_now(false)

      expect(ScopedTestJob.scope_during_perform).not_to have_key(:person)
      expect(ScopedTestJob.scope_during_perform).not_to have_key(:request)
    end

    it 'does not report the scope of the caller with the job error' do
      expect { ScopedTestJob.perform_now(true) }.to raise_error(StandardError, 'oh no')

      expect(Rollbar.last_report[:body][:trace][:extra][:job]).to eq('ScopedTestJob')
      expect(Rollbar.last_report).not_to have_key(:person)
      expect(Rollbar.last_report).not_to have_key(:request)
    end

    it 'restores the scope of the caller afterwards' do
      expect { ScopedTestJob.perform_now(true) }.to raise_error(StandardError)

      expect(Rollbar.scope_object[:person]).to eq(:id => 1)
    end

    context 'with locals enabled',
            :if => RUBY_VERSION >= '2.3.0' &&
                   !(defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby') do
      class LocalsTestJob < ActiveJob::Base
        include Rollbar::ActiveJob

        def perform
          job_local = 'from the job'
          raise StandardError, "oh no #{job_local}"
        end
      end

      before do
        Rollbar.configure do |config|
          config.send_extra_frame_data = :all
          config.locals = { :enabled => true }
        end
      end

      it 'reports the locals of a job run inline, e.g. during a request' do
        # As the Rails middleware does around each request
        Rollbar.notifier.enable_locals
        begin
          expect { LocalsTestJob.perform_now }.to raise_error(StandardError)
        ensure
          Rollbar.notifier.disable_locals
        end

        frame = Rollbar.last_report[:body][:trace][:frames][-1]

        expect(frame[:method]).to match(/perform/)
        expect(frame[:locals]).to include(:job_local => 'from the job')
      end
    end

    context 'when run by one of the Rollbar job integrations' do
      it 'keeps the scope set up for the job' do
        Rollbar::JobIntegration.within { ScopedTestJob.perform_now(false) }

        expect(ScopedTestJob.scope_during_perform[:request]).to eq(:url => '/users/1')
      end

      it 'reports the job error with that scope' do
        expect do
          Rollbar::JobIntegration.within { ScopedTestJob.perform_now(true) }
        end.to raise_error(StandardError, 'oh no')

        expect(Rollbar.last_report[:request]).to eq(:url => '/users/1')
      end
    end
  end
end
