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
end
