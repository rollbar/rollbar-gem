require 'spec_helper'

require 'rollbar/json/oj'

describe Rollbar::JSON::Oj do
  let(:options) do
    {
      :mode => :compat,
      :use_to_json => false,
      :symbol_keys => false,
      :circular => false
    }
  end

  it 'returns correct options' do
    expect(described_class.options).to be_eql(options)
  end
end
