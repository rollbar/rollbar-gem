require 'spec_helper'

describe HomeController do

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

  let(:logger_mock) { double("Rails.logger").as_null_object }

  context "ratchetio controller methods" do
    # TODO run these for a a more-real request
    it "should build valid request data" do
      data = @controller.ratchetio_request_data
      data.should have_key(:params)
      data.should have_key(:url)
      data.should have_key(:user_ip)
      data.should have_key(:headers)
      data.should have_key(:GET)
      data.should have_key(:session)
      data.should have_key(:method)
    end

    it "should build empty person data when no one is logged-in" do
      data = @controller.ratchetio_person_data
      data.should == {}
    end

    context "ratchetio_filter_params" do
      it "should filter files" do
        name = "John Doe"
        file_hash = {
          :filename => "test.txt",
          :type => "text/plain",
          :head => {},
          :tempfile => "dummy"
        }
        file = ActionDispatch::Http::UploadedFile.new(file_hash)

        params = {
          :name => name,
          :a_file => file
        }

        filtered = controller.send(:ratchetio_filtered_params, Ratchetio.configuration.scrub_fields, params)

        filtered[:name].should == name
        filtered[:a_file].should be_a_kind_of(Hash)
        filtered[:a_file][:content_type].should == file_hash[:type]
        filtered[:a_file][:original_filename].should == file_hash[:filename]
        filtered[:a_file][:size].should == file_hash[:tempfile].size
      end

      it "should filter files in nested params" do
        name = "John Doe"
        file_hash = {
          :filename => "test.txt",
          :type => "text/plain",
          :head => {},
          :tempfile => "dummy"
        }
        file = ActionDispatch::Http::UploadedFile.new(file_hash)

        params = {
          :name => name,
          :wrapper => {
            :wrapper2 => {
              :a_file => file,
              :foo => "bar"
            }
          }
        }

        filtered = controller.send(:ratchetio_filtered_params, Ratchetio.configuration.scrub_fields, params)

        filtered[:name].should == name
        filtered[:wrapper][:wrapper2][:foo].should == "bar"

        filtered_file = filtered[:wrapper][:wrapper2][:a_file]
        filtered_file.should be_a_kind_of(Hash)
        filtered_file[:content_type].should == file_hash[:type]
        filtered_file[:original_filename].should == file_hash[:filename]
        filtered_file[:size].should == file_hash[:tempfile].size
      end

      it "should scrub the default scrub_fields" do
        params = {
          :passwd => "hidden",
          :password => "hidden",
          :secret => "hidden",
          :notpass => "visible"
        }

        filtered = controller.send(:ratchetio_filtered_params, Ratchetio.configuration.scrub_fields, params)

        filtered[:passwd].should == "******"
        filtered[:password].should == "******"
        filtered[:secret].should == "******"
        filtered[:notpass].should == "visible"
      end

      it "should scrub custom scrub_fields" do
        Ratchetio.configure do |config|
          config.scrub_fields = [:notpass, :secret]
        end

        params = {
          :passwd => "visible",
          :password => "visible",
          :secret => "hidden",
          :notpass => "hidden"
        }

        filtered = controller.send(:ratchetio_filtered_params, Ratchetio.configuration.scrub_fields, params)

        filtered[:passwd].should == "visible"
        filtered[:password].should == "visible"
        filtered[:secret].should == "******"
        filtered[:notpass].should == "******"
      end
    end

    context "ratchetio_request_url" do
      it "should build simple http urls" do
        req = controller.request
        req.host = 'ratchet.io'

        controller.send(:ratchetio_request_data)[:url].should == 'http://ratchet.io'
      end
    end

    context "ratchetio_user_ip" do
      it "should use X-Real-Ip when set" do
        controller.request.env["HTTP_X_REAL_IP"] = '1.1.1.1'
        controller.request.env["HTTP_X_FORWARDED_FOR"] = '1.2.3.4'
        controller.send(:ratchetio_request_data)[:user_ip].should == '1.1.1.1'
      end

      it "should use X-Forwarded-For when set" do
        controller.request.env["HTTP_X_FORWARDED_FOR"] = '1.2.3.4'
        controller.send(:ratchetio_request_data)[:user_ip].should == '1.2.3.4'
      end

      it "should use the remote_addr when neither is set" do
        controller.send(:ratchetio_request_data)[:user_ip].should == '0.0.0.0'
      end
    end

  end

  describe "GET 'index'" do
    it "should be successful and report a message" do
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'report_exception'" do
    it "should raise a NameError and report an exception" do
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')

      get 'report_exception'
      response.should be_success
    end
  end

  # TODO need to figure out how to make a test request that uses enough of the middleware
  # that it invokes the ratchetio exception catcher. just plain "get 'some_url'" doesn't
  # seem to work.
  context "with error hiding deep inside" do
    let(:cookie_method_name){ :[] }
    let(:original_cookie_method){ ActionDispatch::Cookies::CookieJar.instance_method(cookie_method_name) }
    let(:broken_cookie_method){ Proc.new{ |name| "1" - 1 } }

    before(:each) do
      ActionDispatch::Cookies::CookieJar.send(:define_method, cookie_method_name, broken_cookie_method)
    end

    after(:each) do
      ActionDispatch::Cookies::CookieJar.send(:define_method, cookie_method_name, original_cookie_method)
    end

    it "should report uncaught exceptions" do
      expect {
        get 'current_user'
        Ratchetio.should_receive(:report_exception).once
      }.to raise_exception
    end
  end

  after(:each) do
    Ratchetio.configure do |config|
      config.logger = ::Rails.logger
    end
  end

end
