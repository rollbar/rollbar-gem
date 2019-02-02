require 'spec_helper'
require 'rollbar/rake_tasks'

describe RollbarTest do
  describe '#run' do
    context 'when rollbar is configured' do
      before do
        reset_configuration
        reconfigure_notifier
      end

      it 'raises the test exception' do
        expect { subject.run }.to raise_exception(RollbarTestingException)

        exception_info = Rollbar.last_report[:body][:trace][:exception]
        exception_info[:class].should == 'RollbarTestingException'
      end
    end

    context 'when rollbar is not configured' do
      it 'exits with message' do
        subject.run

        STDOUT.should_receive(:puts).with(subject.token_error_message)
      end
    end
  end
end
