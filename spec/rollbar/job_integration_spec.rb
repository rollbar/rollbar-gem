require 'spec_helper'

describe Rollbar::JobIntegration do
  describe '.within' do
    it 'marks the block as running within a job integration' do
      expect(described_class.within { described_class.within? }).to be(true)
    end

    it 'clears the mark afterwards, also when the block raises' do
      expect { described_class.within { raise 'oh no' } }.to raise_error('oh no')

      expect(described_class.within?).to be(false)
    end

    it 'keeps the mark when nested' do
      described_class.within do
        described_class.within {}

        expect(described_class.within?).to be(true)
      end
    end
  end
end
