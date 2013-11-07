require 'spec_helper'

begin
  require 'rollbar/delay/sucker_punch'
  require 'sucker_punch/testing/inline'
rescue LoadError
end

describe Rollbar::Delay::SuckerPunch, :if => defined?(SuckerPunch) do
  subject { Rollbar::Delay::SuckerPunch.new }

  describe "#call" do
    let(:payload) { "anything" }

    it "performs asynchronously the task" do
      Rollbar.should_receive(:process_payload)

      subject.call payload
    end
  end
end
