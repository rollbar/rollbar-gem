# encoding: utf-8

require 'spec_helper'

require 'rollbar/util'

describe Rollbar::Util do
  describe '.deep_merge' do
    context 'with nil arguments' do
      let(:data) do
        { :foo => :bar }
      end

      it 'doesnt fail and returns same hash' do
        result = Rollbar::Util.deep_merge(nil, data)

        expect(result).to be_eql(data)
      end
    end
  end

  describe '.enforce_valid_utf8' do
    # TODO(jon): all these tests should be removed since they are in
    # in spec/rollbar/encoding/encoder.rb.
    #
    # This should just check that in payload with simple values and
    # nested values are each one passed through Rollbar::Encoding.encode
    context 'with utf8 string and ruby > 1.8' do
      next unless String.instance_methods.include?(:force_encoding)

      let(:payload) { { :foo => 'Изменение' } }

      it 'just returns the same string' do
        payload_copy = payload.clone
        described_class.enforce_valid_utf8(payload_copy)

        expect(payload_copy[:foo]).to be_eql('Изменение')
      end
    end

    it 'should replace invalid utf8 values' do
      bad_key = force_to_ascii("inner \x92bad key")

      payload = {
        :bad_value => force_to_ascii("bad value 1\255"),
        :bad_value_2 => force_to_ascii("bad\255 value 2"),
        force_to_ascii("bad\255 key") => "good value",
        :hash => {
          :inner_bad_value => force_to_ascii("\255\255bad value 3"),
          bad_key.to_sym => 'inner good value',
          force_to_ascii("bad array key\255") => [
            'good array value 1',
            force_to_ascii("bad\255 array value 1\255"),
            {
              :inner_inner_bad => force_to_ascii("bad inner \255inner value")
            }
          ]
        }
      }


      payload_copy = payload.clone
      described_class.enforce_valid_utf8(payload_copy)

      payload_copy[:bad_value].should == "bad value 1"
      payload_copy[:bad_value_2].should == "bad value 2"
      payload_copy["bad key"].should == "good value"
      payload_copy.keys.should_not include("bad\456 key")
      payload_copy[:hash][:inner_bad_value].should == "bad value 3"
      payload_copy[:hash][:"inner bad key"].should == 'inner good value'
      payload_copy[:hash]["bad array key"].should == [
        'good array value 1',
        'bad array value 1',
        {
          :inner_inner_bad => 'bad inner inner value'
        }
      ]
    end
  end
end
