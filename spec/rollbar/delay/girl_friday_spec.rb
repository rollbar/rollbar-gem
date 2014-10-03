require 'spec_helper'

# require girl_friday in the test instead in the implementation
# just to let the user decide to load it or not
require 'girl_friday'
require 'rollbar/delay/girl_friday'

describe Rollbar::Delay::GirlFriday do
  describe '.call' do
    let(:payload) do
      { :key => 'value' }
    end

    it 'push the payload into the queue' do
      expect_any_instance_of(::GirlFriday::WorkQueue).to receive(:push).with(payload)
      described_class.call(payload)
    end
  end
end
