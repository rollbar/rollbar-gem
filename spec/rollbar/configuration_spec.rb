require 'spec_helper'
require 'rollbar/configuration'

describe Rollbar::Configuration do
  if Gem::Version.new(Rails.version) >= Gem::Version.new('4.2.0')
    context 'using rails4.2 and up' do
      require 'rollbar/delay/active_job'

      describe '#use_active_job' do
        context 'with default queue name' do
          it 'enables async and sets ActiveJob as the handler' do
            subject.use_active_job

            expect(subject.use_async).to be_eql(true)
            expect(Rollbar::Delay::ActiveJob.queue_name).to be_eql('default')
            expect(subject.async_handler).to be_eql(Rollbar::Delay::ActiveJob)
          end
        end

        context 'with provided queue name' do
          it 'enables async and sets ActiveJob as the handler' do
            subject.use_active_job(:queue => 'my_test_queue')

            expect(subject.use_async).to be_eql(true)
            expect(Rollbar::Delay::ActiveJob.queue_name).to be_eql('my_test_queue')
            expect(subject.async_handler).to be_eql(Rollbar::Delay::ActiveJob)
          end
        end
      end
    end
  end

  describe '#use_thread' do
    it 'enables async and sets a Thread as handler' do
      subject.use_thread

      expect(subject.use_async).to be_eql(true)
      expect(subject.async_handler).to be_eql(Rollbar::Delay::Thread)
    end
  end

  describe '#use_resque' do
    it 'enables async and sets Resque as the handler' do
      require 'resque'
      subject.use_resque(:queue => 'errors')

      expect(subject.use_async).to be_eql(true)
      expect(subject.async_handler).to be_eql(Rollbar::Delay::Resque)
    end
  end

  describe '#merge' do
    it 'returns a new object with overrided values' do
      subject.environment = 'foo'

      new_config = subject.merge(:environment => 'bar')

      expect(new_config).not_to be(subject)
      expect(new_config.environment).to be_eql('bar')
    end
  end

  describe '#merge!' do
    it 'returns the same object with overrided values' do
      subject.environment = 'foo'

      new_config = subject.merge!(:environment => 'bar')

      expect(new_config).to be(subject)
      expect(new_config.environment).to be_eql('bar')
    end
  end

  describe '#hook' do
    it 'assigns and returns the appropriate hook' do
      subject.hook :on_error_response do
        puts 'foo hook'
      end

      expect(subject.hook(:on_error_response).is_a?(Proc)).to be_eql(true)
    end

    it 'raises a StandardError if requested hook is not supported' do
      expect { subject.hook(:foo) }.to raise_error(StandardError)
    end
  end

  describe '#execute_hook' do
    it 'executes the approriate hook' do
      bar = 'test value'

      subject.hook :on_error_response do
        bar = 'changed value'
      end

      subject.execute_hook :on_error_response

      expect(bar).to be_eql('changed value')
    end
  end
end
