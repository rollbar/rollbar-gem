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
end
