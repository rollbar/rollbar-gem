require 'spec_helper'
require 'rollbar/util/hash'

describe Rollbar::Util::Hash do
  let(:value) do
    {
      :foo => 'bar',
      :bar => {
        :foo => 'bar',
        :bar => [{ :foo => 'bar' }]
      }
    }
  end

  it 'converts the symbol keys to string' do
    new_hash = described_class.deep_stringify_keys(value)

    expect(new_hash['foo']).to be_eql('bar')
    expect(new_hash['bar']['foo']).to be_eql('bar')
    expect(new_hash['bar']['bar'][0]['foo']).to be_eql('bar')
  end

  it 'should replace circular references' do
    a = { :foo => 'bar' }
    b = { :a => a }
    c = { :b => b }
    a[:c] = c # Introduces a cycle

    array1 = %w[a b]
    array2 = ['c', 'd', array1]
    a[:array] = array1

    array1 << array2 # Introduces a cycle

    new_hash = described_class.deep_stringify_keys(a)

    expect(new_hash['c']['b']['a'].include?('removed circular reference')).to be_truthy
    expect(new_hash['array'][2][2].include?('removed circular reference')).to be_truthy
  end

  # https://github.com/rollbar/rollbar-gem/issues/997
  context 'with the same object referenced more than once' do
    let(:reference) { { :key => 'value' } }
    let(:shared) { { :key1 => reference, :key2 => reference } }
    let(:value) { { :key1 => shared, :key2 => shared, :list => [shared, shared] } }
    let(:expected_shared) do
      { 'key1' => { 'key' => 'value' }, 'key2' => { 'key' => 'value' } }
    end

    it 'does not treat repeated references as circular' do
      new_hash = described_class.deep_stringify_keys(value)

      expect(new_hash).to eq(
        'key1' => expected_shared,
        'key2' => expected_shared,
        'list' => [expected_shared, expected_shared]
      )
    end

    it 'does not modify the input' do
      original = Marshal.load(Marshal.dump(value))

      described_class.deep_stringify_keys(value)

      expect(value).to eq(original)
      expect(value[:key2]).to be(shared)
      expect(shared[:key2]).to be(reference)
    end

    it 'works when the repeated objects are frozen' do
      frozen_value = { :key1 => shared.freeze, :key2 => shared, :list => [shared].freeze }

      expect(described_class.deep_stringify_keys(frozen_value)).to eq(
        'key1' => expected_shared,
        'key2' => expected_shared,
        'list' => [expected_shared]
      )
    end
  end

  it 'does not modify circular input' do
    a = { :foo => 'bar' }
    b = { :a => a, :list => [] }
    a[:b] = b
    b[:list] << b

    new_hash = described_class.deep_stringify_keys(a)

    expect(a[:b]).to be(b)
    expect(b[:a]).to be(a)
    expect(b[:list].first).to be(b)
    expect(new_hash['b']['a']).to start_with('removed circular reference')
    expect(new_hash['b']['list'].first).to start_with('removed circular reference')
  end
end
