require 'spec_helper'

require 'rollbar/lazy_store'

describe Rollbar::LazyStore do
  subject { Rollbar::LazyStore.new(data) }
  let(:lazy_value) do
    proc { :bar }
  end
  let(:data) do
    {
      :somekey => :value,
      :foo => lazy_value
    }
  end

  describe '#[]' do
    it 'gets the regular values' do
      expect(subject[:somekey]).to be_eql(:value)
    end

    it 'gets the lazy values and evaluates them just once' do
      expect(lazy_value).to receive(:call).once.and_call_original

      value1 = subject[:foo]
      value2 = subject[:foo]

      expect(value1).to be_eql(:bar)
      expect(value2).to be_eql(:bar)
    end
  end

  describe '#[]=' do
    before do
      # load data in :foo
      subject[:foo]
    end

    it 'sets the data and clears the loaded data' do
      subject[:foo] = 'something-else'

      expect(subject[:foo]).to be_eql('something-else')
    end
  end

  describe '#eql?' do
    context 'passing a Hash' do
      it 'checks correctly eql?' do
        expect(subject.eql?(data)).to be(true)
        expect(subject.eql?({})).to be(false)
      end
    end

    context 'passing a LazyStore' do
      it 'checks correctly eql?' do
        expect(subject.eql?(Rollbar::LazyStore.new(data))).to be(true)
        expect(subject.eql?(Rollbar::LazyStore.new({}))).to be(false)
      end
    end
  end

  describe '#==' do
    context 'passing a Hash' do
      it 'checks correctly eql?' do
        expect(subject == data).to be(true)
        expect(subject == {}).to be(false)
      end
    end

    context 'passing a LazyStore' do
      it 'checks correctly eql?' do
        expect(subject == Rollbar::LazyStore.new(data)).to be(true)
        expect(subject == Rollbar::LazyStore.new({})).to be(false)
      end
    end
  end

  describe '#data' do
    it 'returns the data with lazy values loaded' do
      value = subject.data

      expected_value = {
        :somekey => :value,
        :foo => :bar
      }
      expect(value).to be_eql(expected_value)
    end
  end

  describe '#clone' do
    it 'returns a new object, with same data and empty loaded_data' do
      new_scope = subject.clone

      expect(new_scope.instance_variable_get('@loaded_data')).to be_empty
      expect(new_scope.raw).to be_eql(subject.raw)
    end
  end

  describe '#respond_to_missing?' do
    it 'forwards methods existing on :raw to :raw' do
      expect(subject.respond_to?(:store)).to be(true)
      expect { subject.method(:store) }.not_to raise_error

      expect(data).to receive(:store).with(:foo, :bar)
      subject.store(:foo, :bar)
    end

    it 'does not have methods that do not exist on raw' do
      expect(subject.respond_to?(:baz)).to be(false)
      expect { subject.baz }.to raise_error(NoMethodError)
    end
  end
end
