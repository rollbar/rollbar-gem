require 'spec_helper'

describe HomeController do
  let(:logger_mock) { double("Rails.logger").as_null_object }

  before(:each) do
    reset_configuration
    Ratchetio.configure do |config|
      config.access_token = 'aaaabbbbccccddddeeeeffff00001111'
      config.environment = ::Rails.env
      config.root = ::Rails.root
      config.framework = "Rails: #{::Rails::VERSION::STRING}"
      config.logger = logger_mock
    end
  end

  context "with broken request" do
    it "should report uncaught exceptions" do
      expect{ get 'current_user', nil, cookie: '8%B' }.to raise_exception

      exception_info = Ratchetio.last_report[:body][:trace][:exception]
      exception_info[:class].should == 'ArgumentError'
      exception_info[:message].should == 'invalid %-encoding (8%B)'
    end
  end

  context "with error hiding deep inside" do
    let!(:cookie_method_name){ :[] }
    let!(:original_cookie_method){ ActionDispatch::Cookies::CookieJar.instance_method(cookie_method_name) }
    let!(:broken_cookie_method){ Proc.new{ |name| "1" - 1 } }

    before(:each) do
      ActionDispatch::Cookies::CookieJar.send(:define_method, cookie_method_name, broken_cookie_method)
    end

    after(:each) do
      ActionDispatch::Cookies::CookieJar.send(:define_method, cookie_method_name, original_cookie_method)
    end

    it "should report uncaught exceptions" do
      expect{ get 'current_user' }.to raise_exception

      exception_info = Ratchetio.last_report[:body][:trace][:exception]
      exception_info[:class].should == 'NoMethodError'
      exception_info[:message].should == 'undefined method `-\' for "1":String'
    end
  end
end
