require 'spec_helper'

require 'sidekiq'

Rollbar.plugins.load!

describe Rollbar::Sidekiq::ResetScope, :reconfigure_notifier => false do
  describe '#call' do
    let(:middleware_block) { proc {} }

    it 'calls Rollbar.reset_notifier!' do
      expect(Rollbar).to receive(:reset_notifier!)

      subject.call(nil, nil, nil, &middleware_block)
    end

    context 'when the block calls Rollbar.log without raising an error' do
      let(:middleware_block) { proc { Rollbar.log('warning', 'Danger, Will Robinson') } }
      let(:msg) { { 'class' => 'SomeWorker', 'queue' => 'default' } }

      context 'and Rollbar.configuration.sidekiq_use_scoped_block is false (default)' do
        before do
          Rollbar.configuration.sidekiq_use_scoped_block = false
        end

        it 'does NOT send the scope information to rollbar' do
          expect(Rollbar).to receive(:log) do
            expect(Rollbar.scope_object).not_to be_eql(Rollbar::Sidekiq.job_scope(msg))
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
            expect(Rollbar.scope_object).to be_eql(Rollbar::Sidekiq.job_scope(msg))
          end

          subject.call(nil, msg, nil, &middleware_block)
        end
      end
    end
  end
end
