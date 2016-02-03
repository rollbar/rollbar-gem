require 'spec_helper'

require 'rollbar/scope'


describe Rollbar::Scope do
  let(:scope) { Rollbar::Scope.new(data) }
  let(:lazy_value) do
    proc { :bar }
  end
  let(:data) do
    {
      :somekey => :value,
      :foo => lazy_value
    }
  end

  describe '#method_missing' do
    it 'gets the regular values' do
      expect(scope.somekey).to be_eql(:value)
    end

    it 'gets the lazy values and evaluates them just once' do
      expect(lazy_value).to receive(:call).once.and_call_original

      value1 = scope.foo
      value2 = scope.foo

      expect(value1).to be_eql(:bar)
      expect(value2).to be_eql(:bar)
    end
  end

  describe '#data' do
    it 'returns the data with lazy values loaded' do
      value = scope.data

      expected_value = {
        :somekey => :value,
        :foo => :bar
      }
      expect(value).to be_eql(expected_value)
    end
  end

  describe '#clone' do
    it 'returns a new object, with same data and empty loaded_data' do
      new_scope = scope.clone

      expect(new_scope.instance_variable_get('@loaded_data')).to be_empty
      expect(new_scope.raw).to be_eql(scope.raw)
    end
  end
end
