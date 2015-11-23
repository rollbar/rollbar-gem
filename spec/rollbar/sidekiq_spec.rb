require 'spec_helper'

unless RUBY_VERSION == '1.8.7'
  require 'sidekiq'
  require 'rollbar/sidekiq'
end

describe Rollbar::Sidekiq, :reconfigure_notifier => false do
  describe '.handle_exception' do
    let(:msg_or_context) { ['hello', 'error_backtrace', 'backtrace', 'goodbye'] }
    let(:exception) { StandardError.new('oh noes') }
    let(:rollbar) { double }
    let(:expected_args) { { :request => { :params => ['hello', 'goodbye'] } } }

    subject { described_class }

    it 'constructs scope from filtered params' do
      allow(rollbar).to receive(:error)
      expect(Rollbar).to receive(:scope).with(expected_args) {rollbar}

      described_class.handle_exception(msg_or_context, exception)
    end

    it 'sends the passed-in error to rollbar' do
      allow(Rollbar).to receive(:scope).and_return(rollbar)
      expect(rollbar).to receive(:error).with(exception, :use_exception_level_filters => true)

      described_class.handle_exception(msg_or_context, exception)
    end

    context 'when set a sidekiq_threshold' do
      before do
        Rollbar.configuration.sidekiq_threshold = 2
      end

      it 'does not send error to rollbar under the threshold' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error).never

        msg_or_context = {"retry" => true, "retry_count" => 1}

        described_class.handle_exception(msg_or_context, exception)
      end

      it 'sends the error to rollbar above the threshold' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error)

        msg_or_context = {"retry" => true, "retry_count" => 2}

        described_class.handle_exception(msg_or_context, exception)
      end

      it 'sends the error to rollbar if not retry' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error)

        msg_or_context = {"retry" => false}

        described_class.handle_exception(msg_or_context, exception)
      end
      
      it 'does not blow up and sends the error to rollbar if retry is true but there is no retry count' do
        allow(Rollbar).to receive(:scope).and_return(rollbar)
        expect(rollbar).to receive(:error)

        msg_or_context = {"retry" => true}

        expect {
          described_class.handle_exception(msg_or_context, exception)
        }.to_not raise_error
      end
      
    end
  end

  describe '#call' do
    let(:msg) { ['hello'] }
    let(:exception) { StandardError.new('oh noes') }
    let(:middleware_block) { proc { raise exception } }

    subject { Rollbar::Sidekiq.new }

    it 'sends the error to Rollbar::Sidekiq.handle_exception' do
      expect(Rollbar::Sidekiq).to receive(:handle_exception).with(msg, exception)

      expect { subject.call(nil, msg, nil, &middleware_block) }.to raise_error(exception)
    end
  end
end unless RUBY_VERSION == '1.8.7'
