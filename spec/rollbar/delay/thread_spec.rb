require 'spec_helper'

describe Rollbar::Delay::Thread do
  describe '.call' do
    let(:payload) { { :key => 'value' } }

    it 'process the payload in a new thread' do
      expect(Rollbar).to receive(:process_from_async_handler).with(payload)

      described_class.call(payload).join
    end

    context 'with exceptions processing payload' do
      let(:exception) { StandardError.new }

      before do
        expect(Rollbar).to receive(:process_from_async_handler)
          .with(payload)
          .and_raise(exception)
      end

      it 'doesnt raise any exception' do
        expect do
          described_class.call(payload).join
        end.not_to raise_error
      end

      it 'releases its queue slot' do
        described_class.call(payload).join

        expect(described_class.pending_count).to eq(0)
      end
    end

    context 'with max_queue option' do
      let(:release) { Queue.new }

      before do
        described_class.options = { :max_queue => 2 }

        allow(Rollbar).to receive(:process_from_async_handler) { release.pop }
      end

      after do
        described_class.options = nil
      end

      it 'drops items once max_queue threads are pending' do
        expect(Rollbar).to receive(:log_warning)
          .with('[Rollbar] Thread queue is full (max_queue: 2). ' \
                'Dropping items until a pending report finishes.')

        threads = Array.new(3) { described_class.call(payload) }

        expect(threads[0]).to be_a(::Thread)
        expect(threads[1]).to be_a(::Thread)
        expect(threads[2]).to be_nil
        expect(described_class.pending_count).to eq(2)

        2.times { release << :go }
        threads.compact.each(&:join)

        expect(described_class.pending_count).to eq(0)
      end

      it 'logs one warning each time the queue fills up' do
        expect(Rollbar).to receive(:log_warning).twice

        threads = Array.new(2) { described_class.call(payload) }
        expect(Array.new(3) { described_class.call(payload) }).to all(be_nil)

        release << :go
        Timeout.timeout(5) { sleep 0.01 while described_class.pending_count == 2 }
        threads << described_class.call(payload)
        expect(threads.last).to be_a(::Thread)
        expect(described_class.call(payload)).to be_nil

        2.times { release << :go }
        threads.each(&:join)
      end

      it 'does not carry pending slots into a forked child',
         :if => Process.respond_to?(:fork) do
        threads = Array.new(2) { described_class.call(payload) }
        reader, writer = IO.pipe

        pid = fork do
          reader.close
          release << :go
          count = described_class.pending_count
          thread = described_class.call(payload)
          thread.join if thread
          writer.write("#{count} #{thread.class}")
          writer.close
          exit!(0)
        end

        writer.close
        Process.wait(pid)
        expect(reader.read).to eq('0 Thread')
        reader.close

        expect(described_class.pending_count).to eq(2)
        2.times { release << :go }
        threads.each(&:join)
      end

      it 'accepts items again once pending threads finish' do
        expect(Rollbar).not_to receive(:log_warning)

        2.times do
          threads = Array.new(2) { described_class.call(payload) }
          2.times { release << :go }
          threads.each(&:join)
        end

        expect(described_class.pending_count).to eq(0)
      end

      it 'releases the slot if the thread cannot be created' do
        allow(::Thread).to receive(:new).and_raise(ThreadError)

        expect { described_class.call(payload) }.to raise_error(ThreadError)
        expect(described_class.pending_count).to eq(0)
      end
    end

    context 'without max_queue option' do
      let(:release) { Queue.new }

      before do
        described_class.options = nil

        allow(Rollbar).to receive(:process_from_async_handler) { release.pop }
      end

      it 'does not drop items' do
        expect(Rollbar).not_to receive(:log_warning)

        threads = Array.new(10) { described_class.call(payload) }

        expect(threads).to all(be_a(::Thread))

        10.times { release << :go }
        threads.each(&:join)
      end
    end
  end
end
