require 'spec_helper'
require 'rollbar/rake_tasks'
require 'rollbar/rollbar_test'

describe RollbarTest do
  describe '#run' do
    context 'when rollbar is configured' do
      before do
        reset_configuration
        reconfigure_notifier
      end

      it 'raises the test exception and exits with success message' do
        expect { subject.run }.to output(Regexp.new(subject.success_message)).to_stdout
      end
    end

    context 'when rollbar is not configured' do
      it 'exits with token error message' do
        expect do
          subject.run
        end.to output(Regexp.new(subject.token_error_message)).to_stdout
      end
    end

    context 'when the occurrence fails' do
      before do
        reset_configuration
        reconfigure_notifier
        allow(Rollbar.notifier).to receive(:report).and_raise(StandardError)
      end

      it 'exits with error message' do
        expect { subject.run }.to output(Regexp.new(subject.error_message)).to_stdout
      end
    end
  end
end
