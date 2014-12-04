require 'spec_helper'
require 'rollbar/util/hash'

describe Rollbar::Util::Hash do
  let(:value) do
    {
      :foo => 'bar',
      :bar => {
        :foo => 'bar',
        :bar => [{:foo => 'bar'}]
      },
    }
  end

  it 'converts the symbol keys to string' do
    new_hash = described_class.deep_stringify_keys(value)

    expect(new_hash['foo']).to be_eql('bar')
    expect(new_hash['bar']['foo']).to be_eql('bar')
    expect(new_hash['bar']['bar'][0]['foo']).to be_eql('bar')
  end
end
