require 'spec_helper'

describe Rollbar::Delay::GirlFriday,
         :if => Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.5.0') do

  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.5.0')
    # require girl_friday in the test instead in the implementation
    # to let the user decide to load it or not
    require 'girl_friday'
    require 'rollbar/delay/girl_friday'
  end

  before do
    ::GirlFriday::WorkQueue.immediate!
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
        expect(Rollbar).to receive(:process_from_async_handler)
          .with(payload)
          .and_raise(exception)
      end

      it 'raises an exception cause we are using immediate queue' do
        # This will not happen with a norma work queue cause this:
        # mperham/girl_friday/blob/v0.11.2/lib/girl_friday/work_queue.rb#L90-L106
        expect do
          described_class.call(payload)
        end.to raise_error(exception)
      end
    end
  end
end
