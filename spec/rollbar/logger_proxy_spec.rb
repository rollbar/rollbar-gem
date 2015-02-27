require 'spec_helper'

describe Rollbar::LoggerProxy do
  let(:logger) { double(:logger) }
  let(:message) { 'the-message' }

  subject { described_class.new(logger) }

  shared_examples 'delegate to logger' do
    it 'logs with correct level' do
      expect(logger).to receive(level).with(message)

      subject.send(level, message)
    end
  end

  %w(info error warn debug).each do |level|
    describe "#{level}" do
      it_should_behave_like 'delegate to logger' do
        let(:level) { level }
      end
    end
  end

  describe '#call' do
    context 'if the logger fails' do
      let(:exception) { StandardError.new }
      it 'doesnt raise' do
        allow(logger).to receive(:info).and_raise(exception)

        expect { subject.log('info', message) }.not_to raise_error
      end
    end
  end
end
