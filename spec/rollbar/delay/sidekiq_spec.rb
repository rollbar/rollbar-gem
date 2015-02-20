require 'spec_helper'

begin
  require 'rollbar/delay/sidekiq'
  require 'sidekiq/testing'
rescue LoadError
  module Rollbar
    module Delay
      class Sidekiq
      end
    end
  end
end

describe Rollbar::Delay::Sidekiq, :if => RUBY_VERSION != '1.8.7' do
  let(:payload) { anything }

  describe "#perform" do
    it "performs payload" do
      expect(Rollbar).to receive(:process_payload_safely).with(payload)
      subject.perform payload
    end
  end

  describe "#call" do
    shared_examples "a Rollbar processor" do

      it "processes payload" do
        expect(Rollbar).to receive(:process_payload_safely).with(payload)

        subject.call payload
        described_class.drain
      end
    end

    context "with default options" do
      it "enqueues to default queue" do
        options = Rollbar::Delay::Sidekiq::OPTIONS.merge('args' => payload)
        expect(::Sidekiq::Client).to receive(:push).with(options)

        subject.call payload
      end

      it_behaves_like "a Rollbar processor"
    end

    context "with custom options" do
      let(:custom_config) { { 'queue' => 'custom_queue' } }
      subject { Rollbar::Delay::Sidekiq.new custom_config }

      it "enqueues to custom queue" do
        options = Rollbar::Delay::Sidekiq::OPTIONS.merge(custom_config.merge('args' => payload))
        expect(::Sidekiq::Client).to receive(:push).with(options)

        subject.call payload
      end

      it_behaves_like "a Rollbar processor"
    end
  end
end
