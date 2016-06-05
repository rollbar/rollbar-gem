require 'spec_helper'

require 'rollbar/json/oj'

describe Rollbar::JSON::Oj do
  let(:serializer) do
    Module.new do
      extend Rollbar::JSON
      oj!
    end
  end

  let(:input) { double(:input) }
  let(:result) { double(:result) }

  describe '.dump' do
    it 'calls Oj.dump' do
      expect(::Oj).to receive(:dump).once.with(input, Rollbar::JSON::Oj::OPTIONS) { result }
      expect(serializer.dump(input)).to eq result
    end
  end

  describe '.load' do
    it 'calls Oj.load' do
      expect(::Oj).to receive(:load).once.with(input, Rollbar::JSON::Oj::OPTIONS) { result }
      expect(serializer.load(input)).to eq result
    end
  end
end
