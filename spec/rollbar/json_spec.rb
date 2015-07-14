require 'spec_helper'
require 'rollbar/json'
require 'rollbar/configuration'

describe Rollbar::JSON do
  let(:configuration) do
    Rollbar::Configuration.new
  end

  describe '.dump' do
    context 'with multi_json' do
      before do
        configuration.use_multi_json = true
        Rollbar::JSON.setup(configuration)
      end

      it 'has multi_json as backend' do
        expect(Rollbar::JSON.backend_name).to be_eql(:multi_json)
      end

      it 'calls MultiJson.dump' do
        expect(MultiJson).to receive(:dump).once

        Rollbar::JSON.dump(:foo => :bar)
      end
    end

    context 'with JSON' do
      before do
        configuration.use_multi_json = false
        Rollbar::JSON.setup(configuration)
      end

      it 'has JSON as backend' do
        expect(Rollbar::JSON.backend_name).to be_eql(:json)
      end

      it 'calls JSON.generate' do
        expect(::JSON).to receive(:generate).once

        Rollbar::JSON.dump(:foo => :bar)
      end
    end
  end

  describe '.load' do
    context 'with multi_json' do
      before do
        configuration.use_multi_json = true
        Rollbar::JSON.setup(configuration)
      end

      it 'calls MultiJson.load' do
        expect(MultiJson).to receive(:load).once

        Rollbar::JSON.load(:foo => :bar)
      end
    end

    context 'with multi_json' do
      before do
        configuration.use_multi_json = false
        Rollbar::JSON.setup(configuration)
      end

      it 'calls MultiJson.load' do
        expect(::JSON).to receive(:load).once

        Rollbar::JSON.load(:foo => :bar)
      end
    end
  end

  describe '.load_multi_json' do
    context 'if fails loading multi_json' do
      before do
        allow(Rollbar::JSON).to receive(:require).with('multi_json').and_raise(LoadError)
      end

      it 'finally loads native JSON' do
        expect(Rollbar::JSON).to receive(:load_native_json).once

        Rollbar::JSON.load_multi_json
      end
    end
  end
end
