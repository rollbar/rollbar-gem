require 'spec_helper'

if Gem::Version.new(Rails.version) >= Gem::Version.new('4.2.0')
  context 'using rails4.2 and up' do
    require 'rollbar/delay/active_job'

    describe Rollbar::Delay::ActiveJob do
      include ActiveJob::TestHelper if defined?(ActiveJob::TestHelper) # rubocop:disable Style/MixinUsage

      describe '.call' do
        let(:payload) { {} }
        it 'calls Rollbar' do
          expect(Rollbar).to receive(:process_from_async_handler).with(payload)

          perform_enqueued_jobs do
            Rollbar::Delay::ActiveJob.call(payload)
          end
        end
      end
    end
  end
end
