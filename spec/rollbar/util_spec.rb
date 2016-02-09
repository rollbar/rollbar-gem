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
end
