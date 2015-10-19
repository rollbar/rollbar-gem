require 'spec_helper'

require 'multi_json'
require 'rollbar/json'
require 'rollbar/configuration'

class Rollbar::JSON::MockAdapter
  def self.options
    { 'mock' => 'adapter' }
  end
end

module MultiJson
  module Adapters
    module MockAdapter
    end
  end
end

module MultiJson
  module Adapters
    module MissingCustomOptions
    end
  end
end

module MissingCustomOptions
  # Consider the fact that there's MultiJson::Adapters::Yajl but not
  # Rollbar::JSON::Yajl, it should not look for ::Yajl but only
  # Rollbar::JSON::Yajl.
end

describe Rollbar::JSON do
  let(:payload) do
    { :foo => :bar }
  end
  let(:adapter_options) { { 'option' => 'value' } }

  describe '.dump' do
    before do
      allow(described_class).to receive(:adapter_options).and_return(adapter_options)
    end

    it 'calls MultiJson.dump' do
      expect(::MultiJson).to receive(:dump).once.with(payload, adapter_options)

      described_class.dump(payload)
    end
  end

  describe '.load' do
    before do
      allow(described_class).to receive(:adapter_options).and_return(adapter_options)
    end

    it 'calls MultiJson.load' do
      expect(::MultiJson).to receive(:load).once.with(payload, adapter_options)

      described_class.load(payload)
    end
  end

  describe '.with_adapter' do
    let(:object) { double(:foo => 'bar') }
    let(:callback) do
      proc { object.foo }
    end
    let(:adapter) { described_class.detect_multi_json_adapter }

    it 'calls mock.something with an adapter' do
      expect(MultiJson).to receive(:with_adapter).with(adapter).and_call_original
      expect(object).to receive(:foo).once

      described_class.with_adapter(&callback)
    end
  end

  describe '.detect_multi_json_adapter' do
    
  end

  describe '.adapter_options' do
    it 'calls .options in adapter module' do
      expect(described_class.options_module).to receive(:options)

      described_class.adapter_options
    end
  end

  describe '.options_module' do
    before { described_class.options_module = nil }

    context 'with a defined rollbar adapter' do
      let(:expected_adapter) { Rollbar::JSON::MockAdapter }

      it 'returns the correct options' do
        MultiJson.with_adapter(MultiJson::Adapters::MockAdapter) do
          expect(described_class.options_module).to be(expected_adapter)
        end
      end
    end

    context 'without a defined rollbar adapter' do
      let(:expected_adapter) { Rollbar::JSON::Default }

      it 'returns the correct options' do
        MultiJson.with_adapter(MultiJson::Adapters::MissingCustomOptions) do
          expect(described_class.options_module).to be(expected_adapter)
        end
      end
    end
  end
end
