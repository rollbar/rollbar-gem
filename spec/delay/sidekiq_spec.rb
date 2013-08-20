require 'spec_helper'

begin
  require 'rollbar/delay/sidekiq'
rescue LoadError
end

if defined?(Sidekiq)
  describe Rollbar::Delay::Sidekiq do
    before(:each) do
      reset_configuration
    end
  
    describe ".handler" do
      let(:payload) { anything }
  
      context "with default options" do
        before { Rollbar.configuration.use_sidekiq = true }
  
        it "enqueues to default queue" do
          ::Sidekiq::Client.should_receive(:push).with(Rollbar::Delay::Sidekiq::OPTIONS.merge('args' => payload))
          Rollbar::Delay::Sidekiq.handle(payload)
        end
      end
  
      context "with custom options" do
        let(:custom_config) { { 'queue' => 'custom_queue' } }
  
        before { Rollbar.configuration.use_sidekiq = custom_config }
  
        it "enqueues to custom queue" do
          options = Rollbar::Delay::Sidekiq::OPTIONS.merge(custom_config.merge('args' => payload))
          ::Sidekiq::Client.should_receive(:push).with options
  
          Rollbar::Delay::Sidekiq.handle(payload)
        end
      end
    end
  end
end