require 'spec_helper'

require 'sidekiq' unless RUBY_VERSION == '1.8.7'

Rollbar.plugins.load!

describe Rollbar::Sidekiq, :reconfigure_notifier => false do
  describe '.handle_exception' do
    let(:exception) { StandardError.new('oh noes') }
    let(:rollbar) { double }

    let(:job_hash) do
      {
        'class' => 'FooWorker',
        'args' => %w(foo bar),
        'queue' => 'default',
        'jid' => '96aa59723946616dff537e97',
        'enqueued_at' => Time.now.to_f,
        'error_message' => exception.message,
        'error_class' => exception.class,
        'created_at' => Time.now.to_f,
        'failed_at' => Time.now.to_f,
        'retry' => 3,
        'retry_count' => 0
      }
    end

    let(:ctx_hash) do
      { :context => 'Job raised exception', :job => job_hash }
    end

    let(:expected_scope) do
      {
        :request => {
          :params => job_hash.reject { |k| described_class::PARAM_BLACKLIST.include?(k) }
        },
        :framework => "Sidekiq: #{Sidekiq::VERSION}",
        :context => job_hash['class'],
        :queue => job_hash['queue']
      }
    end

    it 'constructs scope from ctx hash' do
      allow(rollbar).to receive(:error)
      expect(Rollbar).to receive(:scope).with(expected_scope) { rollbar }

      described_class.handle_exception(ctx_hash, exception)
    end

    context 'sidekiq < 4.2.3 ctx hash' do
      let(:ctx_hash) { job_hash }

      it 'constructs scope from ctx hash' do
        allow(rollbar).to receive(:error)
        expect(Rollbar).to receive(:scope).with(expected_scope) { rollbar }

        described_class.handle_exception(ctx_hash, exception)
      end
    end

    context 'sidekiq < 4.0.0 nil ctx hash from Launcher#actor_died' do
      let(:ctx_hash) { nil }

      it 'constructs scope from ctx hash' do
        allow(rollbar).to receive(:error)
        expect(Rollbar).to receive(:scope).with(
          :framework => "Sidekiq: #{Sidekiq::VERSION}"
        ) { rollbar }

        described_class.handle_exception(ctx_hash, exception)
      end
    end

    it 'sends the passed-in error to rollbar' do
      allow(Rollbar).to receive(:scope).and_return(rollbar)
      expect(rollbar).to receive(:error).with(exception, :use_exception_level_filters => true)

      described_class.handle_exception(ctx_hash, exception)
    end

    context 'with fields in job hash to be scrubbed' do
      let(:ctx_hash) do
        {
          :context => 'Job raised exception',
          :job => job_hash.merge(
            'foo' => 'bar',
            'secret' => 'foo',
            'password' => 'foo',
            'password_confirmation' => 'foo'
          )
        }
      end

      before { reconfigure_notifier }

      it 'sends a report with the scrubbed fields' do
        described_class.handle_exception(ctx_hash, exception)

        expect(Rollbar.last_report[:request][:params]).to be_eql_hash_with_regexes(
          'foo' => 'bar',
          'secret' => /\*+/,
          'password' => /\*+/,
          'password_confirmation' => /\*+/
        )
      end
    end

    context 'with a sidekiq_threshold set' do
      before do
        Rollbar.configuration.sidekiq_threshold = 2
      end

      it 'does not send error to rollbar under the threshold' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error).never

        described_class.handle_exception(
          { :job => { 'retry' => true, 'retry_count' => 1 } },
          exception
        )
      end

      it 'sends the error to rollbar above the threshold' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error)

        described_class.handle_exception(
          { :job => { 'retry' => true, 'retry_count' => 2 } },
          exception
        )
      end

      it 'sends the error to rollbar if not retry' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error)

        described_class.handle_exception(
          { :job => { 'retry' => false } },
          exception
        )
      end

      it 'does not blow up and sends the error to rollbar if retry is true but there is no retry count' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error)

        expect do
          described_class.handle_exception(
            { :job => { 'retry' => true } },
            exception
          )
        end.to_not raise_error
      end
    end
  end

  describe '#call' do
    let(:msg) { ['hello'] }
    let(:exception) { StandardError.new('oh noes') }
    let(:middleware_block) { proc { raise exception } }

    subject { Rollbar::Sidekiq.new }

    it 'sends the error to Rollbar::Sidekiq.handle_exception' do
      expect(Rollbar).to receive(:reset_notifier!)
      expect(Rollbar::Sidekiq).to receive(:handle_exception).with(msg, exception)

      expect { subject.call(nil, msg, nil, &middleware_block) }.to raise_error(exception)
    end
  end
end unless RUBY_VERSION == '1.8.7'
