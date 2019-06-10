require 'spec_helper'

begin
  require 'rollbar/delay/shoryuken'
rescue LoadError
  module Rollbar
    module Delay
      class Shoryuken; end
    end
  end
end

describe Rollbar::Delay::Shoryuken do
  describe '.call' do
    let(:payload) do
      { :key => 'value' }
    end

    let(:loaded_hash) do
      Rollbar::JSON.load(Rollbar::JSON.dump(payload))
    end

    it 'process the payload' do
      Shoryuken.worker_executor = Shoryuken::Worker::InlineExecutor
      expect(Rollbar).to receive(:process_from_async_handler).with(loaded_hash)
      described_class.call(payload)
      Shoryuken.worker_executor = Shoryuken::Worker::DefaultExecutor
    end

    context 'with non-default queue name' do
      let(:sqs_queue) { double('non_default_queue') }

      before do
        Rollbar.configure { |config| config.use_shoryuken(:queue => 'non_default_queue') }
      end

      it 'uses specified queue' do
        expect(Shoryuken::Client).to receive(:queues).with('non_default_queue').and_return(sqs_queue)
        expect(sqs_queue).to receive(:send_message)
        described_class.call(payload)
      end
    end
  end
end
