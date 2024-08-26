require 'spec_helper'
require 'rollbar/logger'

describe Rollbar::Logger do
  describe '#add' do
    context 'with severity under level' do
      it 'returns true' do
        result = subject.add(Logger::DEBUG, 'foo')

        expect(result).to be_truthy
      end
    end

    context 'with blank message' do
      it 'returns true' do
        result = subject.add(subject.level)

        expect(result).to be_truthy
      end
    end

    context 'with ERROR severity' do
      let(:message) { 'foo' }

      it 'calls Rollbar to send the message' do
        expect_any_instance_of(Rollbar::Notifier).to receive(:log).with(:error, message)

        subject.add(Logger::ERROR, message)
      end
    end

    context 'with FATAL severity' do
      let(:message) { 'foo' }

      it 'calls Rollbar to send the message with critical level' do
        expect_any_instance_of(Rollbar::Notifier).to receive(:log).with(:critical,
                                                                        message)

        subject.add(Logger::FATAL, message)
      end
    end

    context 'with UNKNOWN severity' do
      let(:message) { 'foo' }

      it 'calls Rollbar to send the message with error level' do
        expect_any_instance_of(Rollbar::Notifier).to receive(:log).with(:error, message)

        subject.add(Logger::UNKNOWN, message)
      end
    end

    context 'with out of range severity' do
      let(:message) { 'foo' }

      it 'calls Rollbar to send the message with error level' do
        expect_any_instance_of(Rollbar::Notifier).to receive(:log).with(:error, message)

        subject.add(10, message)
      end
    end

    context 'without active_support/core_ext/object/blank' do
      let(:message) do
        'foo'.tap do |message|
          message.instance_eval('undef :blank?', __FILE__, __LINE__)
        end
      end

      it 'calls Rollbar to send the message' do
        expect_any_instance_of(Rollbar::Notifier).to receive(:log).with(:error, message)

        subject.add(Logger::ERROR, message)
      end
    end
  end

  describe '#<<' do
    let(:message) { 'foo' }

    it 'calls #error' do
      expect(subject).to receive(:error).with(message)

      subject << message
    end
  end

  describe '#rollbar' do
    it 'returns a Rollbar notifier with a logger pointing to /dev/null' do
      notifier = subject.rollbar
      logger = notifier.configuration.logger
      logdev = logger.instance_eval { @logdev }

      if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0')
        # The Logger class no longer creates a LogDevice when the device is `File::NULL`
        # See: ruby/ruby@f3e12caa088cc893a54bc2810ff511e4c89b322b
        expect(logdev).to be_nil
      else
        expect(logdev.filename).to be_eql('/dev/null')
      end
    end
  end
end
