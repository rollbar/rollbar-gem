require 'spec_helper'
require 'rollbar/rake_tasks'

describe RollbarTest do
  describe '#run' do
    context 'when rollbar is configured' do
      before do
        reset_configuration
        reconfigure_notifier
      end

      it 'raises the test exception and exits with success message' do
        expect { subject.run }.to raise_exception(RollbarTestingException)
          .with_message(Regexp.new(subject.success_message))
      end
    end

    context 'when rollbar is not configured' do
      it 'exits with error message' do
        expect { subject.run }.to output(Regexp.new(subject.token_error_message)).to_stdout
      end
    end
  end
end
