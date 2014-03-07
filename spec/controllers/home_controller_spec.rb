require 'spec_helper'

describe HomeController do
  let(:logger_mock) { double("Rails.logger").as_null_object }

  before(:each) do
    reset_configuration
    Rollbar::Rails.initialize
    Rollbar.configure do |config|
      config.access_token = 'aaaabbbbccccddddeeeeffff00001111'
      config.logger = logger_mock
    end
  end
  
  context "rollbar base_data" do
    it 'should have the Rails environment' do
      data = Rollbar.send(:base_data)
      data[:environment].should == ::Rails.env
    end
    
    it 'should have an overridden environment' do
      Rollbar.configure do |config|
        config.environment = 'dev'
      end
      
      data = Rollbar.send(:base_data)
      data[:environment].should == 'dev'
    end
    
    it 'should use the default "unspecified" environment if rails env ends up being empty' do
      old_env = ::Rails.env
      ::Rails.env = ''
      Rollbar::Rails.initialize
      
      data = Rollbar.send(:base_data)
      data[:environment].should == 'unspecified'
      
      ::Rails.env = old_env
    end
  end

  context "rollbar controller methods with %s requests" % (local? ? 'local' : 'non-local') do
    # TODO run these for a a more-real request
    it "should build valid request data" do
      data = @controller.rollbar_request_data
      data.should have_key(:params)
      data.should have_key(:url)
      data.should have_key(:user_ip)
      data.should have_key(:headers)
      data.should have_key(:session)
      data.should have_key(:method)
      data.should have_key(:route)
    end

    it "should build empty person data when no one is logged-in" do
      data = @controller.rollbar_person_data
      data.should == {}
    end

    context "rollbar_filter_params" do
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

        filtered = controller.send(:rollbar_filtered_params, Rollbar.configuration.scrub_fields, params)

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

        filtered = controller.send(:rollbar_filtered_params, Rollbar.configuration.scrub_fields, params)

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
          :passwd       => "hidden",
          :password     => "hidden",
          :secret       => "hidden",
          :notpass      => "visible",
          :secret_token => "f6805fea1cae0fb79c5e63bbdcd12bc6",
        }

        filtered = controller.send(:rollbar_filtered_params, Rollbar.configuration.scrub_fields, params)

        filtered[:passwd].should == "******"
        filtered[:password].should == "******"
        filtered[:secret].should == "******"
        filtered[:notpass].should == "visible"
        filtered[:secret_token].should == "*" * 32
      end

      it "should scrub custom scrub_fields" do
        Rollbar.configure do |config|
          config.scrub_fields = [:notpass, :secret]
        end

        params = {
          :passwd => "visible",
          :password => "visible",
          :secret => "hidden",
          :notpass => "hidden"
        }

        filtered = controller.send(:rollbar_filtered_params, Rollbar.configuration.scrub_fields, params)

        filtered[:passwd].should == "visible"
        filtered[:password].should == "visible"
        filtered[:secret].should == "******"
        filtered[:notpass].should == "******"
      end
    end

    context 'rollbar_scrub_headers' do

      it 'should filter cookies and authentication by default' do
        headers = {
          'HTTP_AUTHORIZATION' => 'some-user',
          'HTTP_COOKIE' => 'some-cookie',
          'HTTP_USER_AGENT' => 'spec'
        }

        filtered = controller.send( :rollbar_headers, headers )
        filtered.should == {
          "Authorization" => "******************",
          "Cookie" => "***********",
          "User-Agent" => "spec"
        }
      end

      it 'should filter custom headers' do
        Rollbar.configure do |config|
          config.scrub_headers = ['Auth', 'Token']
        end

        headers = {
          'HTTP_AUTH' => 'auth-value',
          'HTTP_TOKEN' => 'token-value',
          'HTTP_CONTENT_TYPE' => 'text/html'
        }

        filtered = controller.send( :rollbar_headers, headers )
        filtered.should == {
          "Auth" => "*********",
          "Token" => "**********",
          "Content-Type" => "text/html"
        }
      end

    end

    context "rollbar_request_url" do
      it "should build simple http urls" do
        req = controller.request
        req.host = 'rollbar.com'

        controller.send(:rollbar_request_data)[:url].should == 'http://rollbar.com'
      end
      
      it "should respect forwarded host" do
        req = controller.request
        req.host = '127.0.0.1:8080'
        req.env['HTTP_X_FORWARDED_HOST'] = 'test.com'

        controller.send(:rollbar_request_data)[:url].should == 'http://test.com'
      end
      
      it "should respect forwarded proto" do
        req = controller.request
        req.host = 'rollbar.com'
        req.env['HTTP_X_FORWARDED_PROTO'] = 'https'

        controller.send(:rollbar_request_data)[:url].should == 'https://rollbar.com'
      end
      
      it "should respect forwarded port" do
        req = controller.request
        req.host = '127.0.0.1:8080'
        req.env['HTTP_X_FORWARDED_HOST'] = 'test.com'
        req.env['HTTP_X_FORWARDED_PORT'] = '80'

        controller.send(:rollbar_request_data)[:url].should == 'http://test.com'
        
        req.env['HTTP_X_FORWARDED_PORT'] = '81'
        controller.send(:rollbar_request_data)[:url].should == 'http://test.com:81'
      end
    end

    context "rollbar_user_ip" do
      it "should use X-Real-Ip when set" do
        controller.request.env["HTTP_X_REAL_IP"] = '1.1.1.1'
        controller.request.env["HTTP_X_FORWARDED_FOR"] = '1.2.3.4'
        controller.send(:rollbar_request_data)[:user_ip].should == '1.1.1.1'
      end

      it "should use X-Forwarded-For when set" do
        controller.request.env["HTTP_X_FORWARDED_FOR"] = '1.2.3.4'
        controller.send(:rollbar_request_data)[:user_ip].should == '1.2.3.4'
      end

      it "should use the remote_addr when neither is set" do
        controller.send(:rollbar_request_data)[:user_ip].should == '0.0.0.0'
      end
    end
    
    context "rollbar_route_params" do
      it "should save route params in request[:route]" do
        route = controller.send(:rollbar_request_data)[:route]
        
        route.should have_key(:controller)
        route.should have_key(:action)
        route.should have_key(:format)
        
        route[:controller].should == 'home'
        route[:action].should == 'index'
      end
      
      it "should save controller and action in the payload body" do
        post 'report_exception'
        
        route = controller.send(:rollbar_request_data)[:route]
        
        route[:controller].should == 'home'
        route[:action].should == 'report_exception'
        
        Rollbar.last_report.should_not be_nil
        Rollbar.last_report[:context].should == 'home#report_exception'
      end
    end

  end

  describe "GET 'index'" do
    it "should be successful and report two messages" do
      logger_mock.should_receive(:info).with('[Rollbar] Success').twice
      get 'index'
      response.should be_success
    end
  end

  describe "'report_exception'", :type => "request" do
    it "should raise a NameError and report an exception after a GET" do
      logger_mock.should_receive(:info).with('[Rollbar] Success').once

      get 'report_exception'
      response.should be_success
    end
    
    it "should raise a NameError and have PUT params in the reported exception" do
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      put 'report_exception', :putparam => "putval"
      
      Rollbar.last_report.should_not be_nil
      Rollbar.last_report[:request][:params]["putparam"].should == "putval"
    end
    
    it "should raise a NameError and have JSON POST params" do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      @request.env["HTTP_ACCEPT"] = "application/json"
      
      params = {:jsonparam => 'jsonval'}.to_json
      post 'report_exception', params, {'CONTENT_TYPE' => 'application/json'}
      
      Rollbar.last_report.should_not be_nil
      Rollbar.last_report[:request][:params]['jsonparam'].should == 'jsonval'
    end
  end
  
  describe "'cause_exception'", :type => "request" do
    it "should raise an uncaught exception and report a message" do
      logger_mock.should_receive(:info).with('[Rollbar] Success').once
      
      expect { get 'cause_exception' }.to raise_exception
    end
    
    context 'show_exceptions' do
      before(:each) do
        if Dummy::Application.respond_to? :env_config
          config = Dummy::Application.env_config
        else
          config = Dummy::Application.env_defaults
        end
        
        config['action_dispatch.show_exceptions'] = true
      end
      
      after(:each) do
        if Dummy::Application.respond_to? :env_config
          config = Dummy::Application.env_config
        else
          config = Dummy::Application.env_defaults
        end
        
        config['action_dispatch.show_exceptions'] = false
      end
      
      it "middleware should catch the exception and only report to rollbar once" do
        logger_mock.should_receive(:info).with('[Rollbar] Success').once
        
        get 'cause_exception'
      end
      
      it 'rollbar request store should extract person data and put it into the reqest' do
        Rollbar.configure do |config|
          config.person_method = 'custom_current_user'
        end
        
        get 'cause_exception'
        
        user = request.env['rollbar.person_data']
        user[:id].should == 123
        user[:username].should == 'test'
        user[:email].should == 'email@test.com'
      end
      
      it 'should not fail if the controller doesnt contain the person method' do
        Rollbar.configure do |config|
          config.person_method = 'invalid_method'
        end
        
        get 'cause_exception'
      end
    end
  end

  after(:each) do
    Rollbar.configure do |config|
      config.logger = ::Rails.logger
    end
  end

end
