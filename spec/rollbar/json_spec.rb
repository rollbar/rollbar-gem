require 'spec_helper'

require 'rollbar/json'
require 'rollbar/configuration'

describe Rollbar::JSON do
  let(:payload) do
    { :foo => :bar }
  end

  describe '.dump' do
    it 'calls JSON.generate' do
      expect(::JSON).to receive(:generate).once.with(payload)

      described_class.dump(payload)
    end
  end

  describe '.load' do
    it 'calls JSON.parse' do
      expect(::JSON).to receive(:parse).once.with(payload)

      described_class.load(payload)
    end
  end
end
