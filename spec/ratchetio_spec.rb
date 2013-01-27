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

    it 'should not report exceptions when silenced' do
      Ratchetio.should_not_receive :schedule_payload

      begin
        test_var = 1
        Ratchetio.silenced do
          test_var = 2
          raise
        end
      rescue => e
        Ratchetio.report_exception(e)
      end

      test_var.should == 2
    end

    it 'should report exception objects with no backtrace' do
      payload = nil
      Ratchetio.stub(:schedule_payload) do |*args|
        payload = JSON.parse( args[0] )
      end
      Ratchetio.report_exception(StandardError.new("oops"))
      payload["data"]["body"]["trace"]["frames"].should == []
      payload["data"]["body"]["trace"]["exception"]["class"].should == "StandardError"
      payload["data"]["body"]["trace"]["exception"]["message"].should == "oops"
    end

    it 'should return the exception data with a uuid, on platforms with SecureRandom' do
      if defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)
        Ratchetio.stub(:schedule_payload) do |*args| end
        exception_data = Ratchetio.report_exception(StandardError.new("oops"))
        exception_data[:uuid].should_not be_nil
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
      logger_mock.should_receive(:info).with('[Ratchet.io] Scheduling payload')
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

  context 'payload_destination' do
    before(:each) do
      configure
      Ratchetio.configure do |config|
        config.logger = logger_mock
        config.filepath = 'test.ratchet'
      end

      begin
        foo = bar
      rescue => e
        @exception = e
      end
    end

    let(:logger_mock) { double("Rails.logger").as_null_object }

    it 'should send the payload over the network by default' do
      logger_mock.should_not_receive(:info).with('[Ratchet.io] Writing payload to file')
      logger_mock.should_receive(:info).with('[Ratchet.io] Sending payload')
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')
      Ratchetio.report_exception(@exception)
    end

    it 'should save the payload to a file if set' do
      logger_mock.should_not_receive(:info).with('[Ratchet.io] Sending payload')
      logger_mock.should_receive(:info).with('[Ratchet.io] Writing payload to file')
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')

      filepath = ''

      Ratchetio.configure do |config|
        config.write_to_file = true
        filepath = config.filepath
      end

      Ratchetio.report_exception(@exception)

      File.exist?(filepath).should == true
      File.read(filepath).should include test_access_token
      File.delete(filepath)

      Ratchetio.configure do |config|
        config.write_to_file = false
      end
    end
  end

  context 'asynchronous_handling' do
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

    it 'should send the payload using the default asynchronous handler girl_friday' do
      logger_mock.should_receive(:info).with('[Ratchet.io] Scheduling payload')
      logger_mock.should_receive(:info).with('[Ratchet.io] Sending payload')
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')

      Ratchetio.configure do |config|
        config.use_async = true
        GirlFriday::WorkQueue::immediate!
      end

      Ratchetio.report_exception(@exception)

      Ratchetio.configure do |config|
        config.use_async = false
        GirlFriday::WorkQueue::queue!
      end
    end

    it 'should send the payload using a user-supplied asynchronous handler' do
      logger_mock.should_receive(:info).with('Custom async handler called')
      logger_mock.should_receive(:info).with('[Ratchet.io] Sending payload')
      logger_mock.should_receive(:info).with('[Ratchet.io] Success')

      Ratchetio.configure do |config|
        config.use_async = true
        config.async_handler = Proc.new { |payload|
          logger_mock.info 'Custom async handler called'
          Ratchetio.process_payload(payload)
        }
      end

      Ratchetio.report_exception(@exception)

      Ratchetio.configure do |config|
        config.use_async = false
        config.async_handler = Ratchetio.method(:default_async_handler)
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

end
