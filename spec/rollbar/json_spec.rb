require 'spec_helper'
require 'rollbar/json'
require 'rollbar/configuration'

describe Rollbar::JSON do
  before do
    Rollbar::JSON.setup
  end

  let(:payload) do
    { :foo => :bar }
  end

  let(:options) do
    {
      :mode => :compat,
      :use_to_json => false,
      :symbol_keys => false,
      :circular => false
    }
  end

  describe '.dump' do
    it 'has JSON as backend' do
      expect(Rollbar::JSON.backend_name).to be_eql(:oj)
    end


    it 'calls JSON.generate' do
      expect(::Oj).to receive(:dump).once.with(payload, options)

      Rollbar::JSON.dump(payload)
    end
  end

  describe '.load' do
    it 'calls MultiJson.load' do
      expect(::Oj).to receive(:load).once.with(payload, options)

      Rollbar::JSON.load(payload)
    end
  end
end
