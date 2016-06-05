require 'spec_helper'

require 'rollbar/json'
require 'rollbar/configuration'

describe Rollbar::JSON do
  let(:serializer) { Module.new { extend Rollbar::JSON } }
  let(:input) { double(:input) }
  let(:result) { double(:result) }

  describe '.dump' do
    it 'calls JSON.dump' do
      expect(::JSON).to receive(:dump).once.with(input) { result }
      expect(serializer.dump(input)).to eq result
    end
  end

  describe '.load' do
    it 'calls JSON.load' do
      expect(::JSON).to receive(:load).once.with(input) { result }
      expect(serializer.load(input)).to eq result
    end
  end
end
