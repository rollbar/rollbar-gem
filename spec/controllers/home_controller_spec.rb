require 'spec_helper'

describe HomeController do
  
  before(:each) do
    Ratchetio.configure do |config|
      config.logger = logger_mock
    end
  end
    
  let(:logger_mock) { double("Rails.logger").as_null_object }

  describe "GET 'index'" do
    it "should be successful and report a message" do
      logger_mock.should_receive(:info).with('[Ratchet.io] Sending payload')
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'report_exception'" do
    it "should raise a NameError and report an exception" do
      logger_mock.should_receive(:info).with('[Ratchet.io] Sending payload')

      get 'report_exception'
      response.should be_success
    end
  end

  # TODO need to figure out how to make a test request that uses enough of the middleware
  # that it invokes the ratchetio exception catcher. just plain "get 'some_url'" doesn't
  # seem to work.
  it "should report uncaught exceptions"
  
  after(:each) do
    Ratchetio.configure do |config|
      config.logger = ::Rails.logger
    end
  end
  
end
