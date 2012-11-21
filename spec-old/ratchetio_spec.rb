require 'spec_helper'

describe Ratchetio do
  it 'should have the notifier name in the base_data' do
    Ratchetio.send(:base_data).should == 'ratchetio-gem'
  end
end
