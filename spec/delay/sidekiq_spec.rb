require 'spec_helper'

begin
  require 'rollbar/delay/sidekiq'
rescue LoadError
end

if defined?(Sidekiq)
  describe Rollbar::Delay::Sidekiq do
    let(:payload) { anything }
  
    describe "#perform" do
      it "performs payload" do
        Rollbar.should_receive(:process_payload).with(payload)
        subject.perform payload
      end
    end

    describe "#call" do
      context "with default options" do
        it "enqueues to default queue" do
          options = Rollbar::Delay::Sidekiq::OPTIONS.merge('args' => payload)
          ::Sidekiq::Client.should_receive(:push).with options

          subject.call payload
        end
      end

      context "with custom options" do
        let(:custom_config) { { 'queue' => 'custom_queue' } }
        subject { Rollbar::Delay::Sidekiq.new custom_config }

        it "enqueues to custom queue" do
          options = Rollbar::Delay::Sidekiq::OPTIONS.merge(custom_config.merge('args' => payload))
          ::Sidekiq::Client.should_receive(:push).with options

          subject.call payload
        end
      end
    end
  end
end
