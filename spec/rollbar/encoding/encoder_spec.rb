# encoding: UTF-8

require 'spec_helper'
require 'rollbar/encoding/encoder'

describe Rollbar::Encoding::Encoder do
  subject { described_class.new(object) }

  shared_examples 'encoding' do
    it 'encodes ir properly' do
      value = subject.encode

      expect(value).to be_eql(expected)
    end
  end

  describe '#encode' do
    context 'with ascii chars at end of string' do
      it_behaves_like 'encoding' do
        let(:object) { force_to_ascii("bad value 1\255") }
        let(:expected) { 'bad value 1' }
      end
    end

    context 'with ascii chars at middle of string' do
      it_behaves_like 'encoding' do
        let(:object) { force_to_ascii("bad\255 value 2") }
        let(:expected) { 'bad value 2' }
      end
    end

    context 'with ascii chars at end of string' do
      it_behaves_like 'encoding' do
        let(:object) { force_to_ascii("bad value 3\255") }
        let(:expected) { 'bad value 3' }
      end
    end

    context '0xa0 char in exception object' do
      it_behaves_like 'encoding' do
        let(:object) { "foo \xa0".force_encoding(::Encoding::ISO_8859_1) }
        let(:expected) { 'foo ' }
      end
    end

    context 'with bad symbol' do
      it_behaves_like 'encoding' do
        let(:bad_string) { force_to_ascii("inner \x92bad key") }
        let(:object) { bad_string.to_sym }
        let(:expected) { :"inner bad key" }
      end
    end

    context 'with russian chars in string' do
      it_behaves_like 'encoding' do
        let(:object) { 'Изменение' }
        let(:expected) { 'Изменение' }
      end
    end

    context 'with unmappable encoding' do
      # The Vietnamese encoding Windows-1258 has some character sequences
      # that cannot map to UTF-8. Use this to cause Encoding::ConverterNotFoundError
      # and test the behavior of unmappble encodings.
      let(:object) { "\xE3\xEC".force_encoding(::Encoding::Windows_1258) }
      let(:expected) { 'error encoding string: Encoding::ConverterNotFoundError' }

      it 'replaces string with diagnostic error' do
        value = subject.encode

        expect(value).to include(expected)
      end
    end
  end
end
