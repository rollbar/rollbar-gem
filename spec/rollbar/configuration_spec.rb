require 'spec_helper'
require 'rollbar/configuration'

describe Rollbar::Configuration do

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
end
