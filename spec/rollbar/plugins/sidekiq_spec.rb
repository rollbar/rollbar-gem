require 'spec_helper'

require 'sidekiq'

Rollbar.plugins.load!

describe Rollbar::Sidekiq, :reconfigure_notifier => false do
  describe '.handle_exception' do
    let(:exception) { StandardError.new('oh noes') }
    let(:rollbar) { double }

    let(:job_hash) do
      {
        'class' => 'FooWorker',
        'args' => %w[foo bar],
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

    let(:msg) do
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

    it 'constructs scope from msg' do
      allow(rollbar).to receive(:error)
      expect(Rollbar).to receive(:scope).with(expected_scope) { rollbar }

      described_class.handle_exception(msg, exception)
    end

    context 'sidekiq < 4.2.3 msg' do
      let(:msg) { job_hash }

      it 'constructs scope from msg' do
        allow(rollbar).to receive(:error)
        expect(Rollbar).to receive(:scope).with(expected_scope) { rollbar }

        described_class.handle_exception(msg, exception)
      end
    end

    context 'sidekiq < 4.0.0 nilmsg from Launcher#actor_died' do
      let(:msg) { nil }

      it 'constructs scope from msg' do
        allow(rollbar).to receive(:error)
        expect(Rollbar).to receive(:scope).with(
          :framework => "Sidekiq: #{Sidekiq::VERSION}"
        ) { rollbar }

        described_class.handle_exception(msg, exception)
      end
    end

    it 'sends the passed-in error to rollbar' do
      allow(Rollbar).to receive(:scope).and_return(rollbar)
      expect(rollbar).to receive(:error).with(exception,
                                              :use_exception_level_filters => true)

      described_class.handle_exception(msg, exception)
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
        Rollbar.configuration.sidekiq_threshold = 3
      end

      it 'sends error to Rollbar if it is not a retry attempt' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error).once

        described_class.handle_exception(
          { :job => { 'retry' => true } },
          exception
        )
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
    end
  end

  describe '#call' do
    let(:msg) { { 'class' => 'SomeWorker', 'queue' => 'default' } }
    let(:exception) { StandardError.new('oh noes') }
    let(:middleware_block) { proc { raise exception } }

    subject { Rollbar::Sidekiq.new }

    it 'sends the error to Rollbar::Sidekiq.handle_exception' do
      expect(Rollbar).to receive(:reset_notifier!)
      expect(Rollbar::Sidekiq).to receive(:handle_exception).with(msg, exception)

      expect { subject.call(nil, msg, nil, &middleware_block) }.to raise_error(exception)
    end

    context 'when the block calls Rollbar.log without raising an error' do
      let(:middleware_block) { proc { Rollbar.log('warning', 'Danger, Will Robinson') } }

      context 'and Rollbar.configuration.sidekiq_use_scoped_block is false (default)' do
        before do
          Rollbar.configuration.sidekiq_use_scoped_block = false
        end

        it 'does NOT send the scope information to rollbar' do
          expect(Rollbar).to receive(:log) do
            expect(Rollbar.scope_object).not_to be_eql(described_class.job_scope(msg))
          end

          subject.call(nil, msg, nil, &middleware_block)
        end
      end

      context 'and Rollbar.configuration.sidekiq_use_scoped_block is true' do
        before do
          Rollbar.configuration.sidekiq_use_scoped_block = true
        end

        it 'sends the scope information to rollbar' do
          expect(Rollbar).to receive(:log) do
            expect(Rollbar.scope_object).to be_eql(described_class.job_scope(msg))
          end

          subject.call(nil, msg, nil, &middleware_block)
        end
      end
    end
  end
end
