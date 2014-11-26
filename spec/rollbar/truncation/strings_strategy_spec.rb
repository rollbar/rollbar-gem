# encoding: UTF-8

require 'spec_helper'
require 'rollbar/truncation/frames_strategy'

describe Rollbar::Truncation::StringsStrategy do
  describe '.call' do
    let(:long_message) { 'a' * 2000 }
    let(:payload) do
      {
        :truncated => long_message,
        :not_truncated => '123456',
        :hash => {
          :inner_truncated => long_message,
          :inner_not_truncated => '567',
          :array => ['12345678', '12', { :inner_inner => long_message }]
        }
      }
    end

    it 'should truncate all nested strings in the payload' do
      result = MultiJson.load(described_class.call(payload)).deep_symbolize_keys

      expect(result[:truncated].size).to be_eql(1024)
      expect(result[:hash][:inner_truncated].size).to be_eql(1024)
      expect(result[:hash][:array][2][:inner_inner].size).to be_eql(1024)
    end

    context 'with utf8 strings' do
      let(:long_message) { 'Ŝǻмρļẻ śţяịņģ' + 'a' * 2000 }
      let(:payload) do
        {
          :truncated => long_message,
          :not_truncated => '123456',
        }
      end

      it 'should truncate utf8 strings properly' do
        result = MultiJson.load(described_class.call(payload)).deep_symbolize_keys
        expect(result[:truncated]).to match(/^Ŝǻмρļẻ śţяịņģa*\.{3}/)
      end
    end

    context 'when first threshold is not enough' do
      let(:payload) do
        129.times.to_enum.reduce({}) do |hash, i|
          hash[i.to_s] = 'a' * 1024
          hash
        end
      end

      it 'truncates to 512 size strings' do
        result = MultiJson.load(described_class.call(payload))

        expect(result['0'].size).to be_eql(512)
      end
    end

    context 'when second threshold is still not enough' do
      let(:payload) do
        257.times.to_enum.reduce({}) do |hash, i|
          hash[i.to_s] = 'a' * 1024
          hash
        end
      end

      it 'truncates to 256 size strings, the third threshold' do
        result = MultiJson.load(described_class.call(payload))

        expect(result['0'].size).to be_eql(256)
      end
    end

    context 'when third threshold is still not enough' do
      let(:payload) do
        1024.times.to_enum.reduce({}) do |hash, i|
          hash[i.to_s] = 'a' * 1024
          hash
        end
      end

      it 'just return the value for third threshold' do
        result = MultiJson.load(described_class.call(payload))

        expect(result['0'].size).to be_eql(256)
      end
    end
  end
end
