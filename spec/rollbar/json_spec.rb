require 'spec_helper'
require 'rollbar/json'
require 'rollbar/configuration'

describe Rollbar::JSON do
  before do
    Rollbar::JSON.setup
  end

  describe '.dump' do
    it 'has JSON as backend' do
      expect(Rollbar::JSON.backend_name).to be_eql(:json)
    end

    it 'has correct json output' do
      expect(Rollbar::JSON.dump(:foo => :bar)).to eq("{\"foo\":\"bar\"}")
    end
  end

  describe '.load' do
    it 'calls MultiJson.load' do
      expect(::JSON).to receive(:load).once

      Rollbar::JSON.load(:foo => :bar)
    end
  end
end
