require 'spec_helper'

# require girl_friday in the test instead in the implementation
# just to let the user decide to load it or not
require 'girl_friday'
require 'rollbar/delay/girl_friday'

describe Rollbar::Delay::GirlFriday do
  before do
    queue_class = ::GirlFriday::WorkQueue.immediate!
    allow(::Rollbar::Delay::GirlFriday).to receive(:queue_class).and_return(queue_class)
  end

  describe '.call' do
    let(:payload) do
      { :key => 'value' }
    end

    it 'push the payload into the queue' do
      expect(Rollbar).to receive(:process_from_async_handler).with(payload)

      described_class.call(payload)
    end

    context 'with exceptions processing payload' do
      let(:exception) { Exception.new }

      before do
        expect(Rollbar).to receive(:process_from_async_handler).with(payload).and_raise(exception)
      end

      it 'raises an exception cause we are using immediate queue' do
        # This will not happen with a norma work queue cause this:
        # https://github.com/mperham/girl_friday/blob/master/lib/girl_friday/work_queue.rb#L90-L106
        expect do
          described_class.call(payload)
        end.to raise_error(exception)
      end
    end
  end
end
