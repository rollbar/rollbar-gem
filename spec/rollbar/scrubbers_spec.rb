require 'spec_helper'

require 'rollbar/scrubbers'

describe Rollbar::Scrubbers do
  describe '.scrub_value' do
    context 'with random scrub length' do
      before do
        allow(Rollbar.configuration).to receive(:randomize_scrub_length).and_return(true)
      end

      let(:value) { 'herecomesaverylongvalue' }

      it 'randomizes the scrubbed string' do
        expect(described_class.scrub_value(value)).to match(/\*{3,8}/)
      end
    end

    context 'with no-random scrub length' do
      before do
        allow(Rollbar.configuration).to receive(:randomize_scrub_length).and_return(false)
      end

      let(:value) { 'herecomesaverylongvalue' }

      it 'randomizes the scrubbed string' do
        expect(described_class.scrub_value(value)).to match(/\*{#{value.length}}/)
      end
    end
  end
end
