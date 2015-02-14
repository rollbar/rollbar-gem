require 'spec_helper'

begin
  require 'rollbar/delay/sucker_punch'
  require 'sucker_punch/testing/inline'
rescue LoadError
  module Rollbar
    module Delay
      class SuckerPunch
      end
    end
  end
end

describe Rollbar::Delay::SuckerPunch, :if => RUBY_VERSION != '1.8.7' do
  describe ".call" do
    let(:payload) { "anything" }

    it "performs the task asynchronously" do
      allow(Rollbar).to receive(:process_payload_safely)

      Rollbar::Delay::SuckerPunch.call payload
    end
  end
end
