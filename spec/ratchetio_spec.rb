require 'logger'
require 'socket'
require 'spec_helper'

describe Ratchetio do

  context 'report_exception' do
    before(:each) do
      configure
      Ratchetio.configure do |config|
        config.logger = logger_mock
      end
      
      begin
        foo = bar
      rescue => e
        @exception = e
      end
    end
   
    let(:logger_mock) { double("Rails.logger").as_null_object }

    it 'should report exceptions without person or request data' do
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')
      Ratchetio.report_exception(@exception)
    end

    it 'should not report anything when disabled' do
      logger_mock.should_not_receive(:info).with('[Ratchet.io] Success')
      Ratchetio.configure do |config|
        config.enabled = false
      end
      
      Ratchetio.report_exception(@exception)
      
      Ratchetio.configure do |config|
        config.enabled = true
      end
    end

    it 'should report exceptions with request and person data' do
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')
      request_data = {
        :params => { :foo => "bar" },
        :url => 'http://localhost/',
        :user_ip => '127.0.0.1',
        :headers => {},
        :GET => { "baz" => "boz" },
        :session => { :user_id => 123 },
        :method => "GET",
      }
      person_data = {
        :id => 1,
        :username => "test",
        :email => "test@example.com"
      }
      Ratchetio.report_exception(@exception, request_data, person_data)
    end

    it 'should ignore ignored exception classes' do
      saved_filters = Ratchetio.configuration.exception_level_filters
      Ratchetio.configure do |config|
        config.exception_level_filters = { 'NameError' => 'ignore' }
      end

      logger_mock.should_not_receive(:info)
      logger_mock.should_not_receive(:warn)
      logger_mock.should_not_receive(:error)
      
      Ratchetio.report_exception(@exception)
      
      Ratchetio.configure do |config|
        config.exception_level_filters = saved_filters
      end
    end
  end
  
  context 'report_message' do
    before(:each) do
      configure
      Ratchetio.configure do |config|
        config.logger = logger_mock
      end
    end
    
    let(:logger_mock) { double("Rails.logger").as_null_object }

    it 'should report simple messages' do
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')
      Ratchetio.report_message("Test message")
    end

    it 'should not report anything when disabled' do
      logger_mock.should_not_receive(:info).with('[Ratchet.io] Success')
      Ratchetio.configure do |config|
        config.enabled = false
      end
      
      Ratchetio.report_message("Test message that should be ignored")
      
      Ratchetio.configure do |config|
        config.enabled = true
      end
    end

    it 'should report messages with extra data' do
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')
      Ratchetio.report_message("Test message with extra data", 'debug', :foo => "bar",
                               :hash => { :a => 123, :b => "xyz" })
    end

    it 'should not crash with circular extra_data' do
      a = { :foo => "bar" }
      b = { :a => a }
      c = { :b => b }
      a[:c] = c

      logger_mock.should_receive(:error).with('[Ratchet.io] Error reporting message to Ratchet.io: object references itself')
      Ratchetio.report_message("Test message with extra data", 'debug', a)
    end

    after(:each) do
      Ratchetio.configure do |config|
        config.logger = ::Rails.logger
      end
    end
  end

  context 'message_data' do
    before(:each) do
      configure
      @message_body = "This is a test"
      @level = 'debug'
    end

    it 'should build a message' do
      data = Ratchetio.send(:message_data, @message_body, @level, {})
      data[:body][:message][:body].should == @message_body
      data[:level].should == @level
    end

    it 'should accept extra_data' do
      user_id = 123
      name = "Tester"

      data = Ratchetio.send(:message_data, @message_body, 'info', 
                            :user_id => user_id, :name => name)
      
      message = data[:body][:message]
      message[:body].should == @message_body
      message[:user_id].should == user_id
      message[:name].should == name
    end
  end
  
  context 'exception_data' do
    before(:each) do
      configure
      begin
        foo = bar
      rescue => e
        @exception = e
      end
    end
    
    it 'should accept force_level' do
      level = 'critical'
      data = Ratchetio.send(:exception_data, @exception, level)
      data[:level].should == level
    end

    it 'should build valid exception data' do
      data = Ratchetio.send(:exception_data, @exception)
      
      data[:level].should_not be_nil
      
      trace = data[:body][:trace]
      
      frames = trace[:frames]
      frames.should be_a_kind_of(Array)
      frames.each do |frame|
        frame[:filename].should be_a_kind_of(String)
        frame[:lineno].should be_a_kind_of(Fixnum)
        if frame[:method]
          frame[:method].should be_a_kind_of(String)
        end
      end
      
      # should be NameError, but can be NoMethodError sometimes on rubinius 1.8
      # http://yehudakatz.com/2010/01/02/the-craziest-fing-bug-ive-ever-seen/
      trace[:exception][:class].should match(/^(NameError|NoMethodError)$/)
      trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
    end
  end
  
  context 'logger' do
    before(:each) do
      reset_configuration
    end

    it 'should have use the Rails logger when configured to do so' do
      configure
      Ratchetio.send(:logger).should == ::Rails.logger
    end

    it 'should use the default_logger when no logger is set' do
      logger = Logger.new(STDERR)
      Ratchetio.configure do |config|
        config.default_logger = lambda { logger }
      end
      Ratchetio.send(:logger).should == logger
    end

    it 'should have a default default_logger' do
      Ratchetio.send(:logger).should_not be_nil
    end

    after(:each) do
      reset_configuration
    end
  end
  
  context 'build_payload' do
    it 'should build valid json' do
      json = Ratchetio.send(:build_payload, {:foo => {:bar => "baz"}})
      hash = ActiveSupport::JSON.decode(json)
      hash["data"]["foo"]["bar"].should == "baz"
    end
  end

  context 'base_data' do
    before(:each) do
      configure
    end

    it 'should have the correct notifier name' do
      Ratchetio.send(:base_data)[:notifier][:name].should == 'ratchetio-gem'
    end
    
    it 'should have the correct notifier version' do
      Ratchetio.send(:base_data)[:notifier][:version].should == Ratchetio::VERSION
    end

    it 'should have all the required keys' do
      data = Ratchetio.send(:base_data)
      data[:timestamp].should_not be_nil
      data[:environment].should_not be_nil
      data[:level].should_not be_nil
      data[:language].should == 'ruby'
      data[:framework].should match(/^Rails/)
    end
  end

  context 'server_data' do
    it 'should have the right hostname' do
      Ratchetio.send(:server_data)[:host] == Socket.gethostname
    end

    it 'should have root and branch set when configured' do
      configure
      Ratchetio.configure do |config|
        config.root = '/path/to/root'
        config.branch = 'master'
      end

      data = Ratchetio.send(:server_data)
      data[:root].should == '/path/to/root'
      data[:branch].should == 'master'
    end
  end

  # configure with some basic params
  def configure
    Ratchetio.configure do |config|
      # special test access token
      config.access_token = test_access_token
      config.logger = ::Rails.logger
      config.environment = ::Rails.env
      config.root = ::Rails.root
      config.framework = "Rails: #{::Rails::VERSION::STRING}"
    end
  end

  def test_access_token
    'aaaabbbbccccddddeeeeffff00001111'
  end

  def reset_configuration
    Ratchetio.configure do |config|
      config.access_token = nil
      config.branch = nil
      config.default_logger = lambda { Logger.new(STDERR) }
      config.enabled = true
      config.endpoint = Ratchetio::Configuration::DEFAULT_ENDPOINT
      config.environment = nil
      config.exception_level_filters = {
        'ActiveRecord::RecordNotFound' => 'warning',
        'AbstractController::ActionNotFound' => 'warning',
        'ActionController::RoutingError' => 'warning'
      }
      config.framework = 'Plain'
      config.logger = nil
      config.person_method = 'current_user'
      config.person_id_method = 'id'
      config.person_username_method = 'username'
      config.person_email_method = 'email'
      config.root = nil
    end
  end

end
