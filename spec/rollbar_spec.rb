# encoding: UTF-8

require 'logger'
require 'socket'
require 'spec_helper'
require 'girl_friday'

begin
  require 'sucker_punch'
  require 'sucker_punch/testing/inline'
rescue LoadError
end

describe Rollbar do
  
  context 'Notifier' do
    context 'log' do
      let(:exception) do
        begin
          foo = bar
        rescue => e
          e
        end
      end
      
      let (:notifier) do
        notifier = Rollbar.scope
        notifier.stub(:report)
        notifier
      end
      
      it 'should report a simple message' do
        notifier.log('error', 'test message')
        expect(notifier).to have_received(:report).with('error', 'test message', nil, nil)
      end
      
      it 'should report a simple message with extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        
        notifier.log('error', 'test message', extra_data)
        expect(notifier).to have_received(:report).with('error', 'test message', nil, extra_data)
      end
      
      it 'should report an exception' do
        notifier.log('error', exception)
        expect(notifier).to have_received(:report).with('error', nil, exception, nil)
      end
      
      it 'should report an exception with extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        
        notifier.log('error', exception, extra_data)
        expect(notifier).to have_received(:report).with('error', nil, exception, extra_data)
      end
      
      it 'should report an exception with a description' do
        notifier.log('error', exception, 'exception description')
        expect(notifier).to have_received(:report).with('error', 'exception description', exception, nil)
      end
      
      it 'should report an exception with a description and extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        
        notifier.log('error', exception, extra_data, 'exception description')
        expect(notifier).to have_received(:report).with('error', 'exception description', exception, extra_data)
      end
    end
    
    context 'debug/info/warning/error/critical' do
      let(:exception) do
        begin
          foo = bar
        rescue => e
          e
        end
      end
      
      let (:notifier) do
        notifier = Rollbar.scope
        notifier.stub(:report)
        notifier
      end
      
      let (:extra_data) { {:key => 'value', :hash => {:inner_key => 'inner_value'}} }

      it 'should report with a debug level' do
        notifier.debug(exception)
        expect(notifier).to have_received(:report).with('debug', nil, exception, nil)
        
        notifier.debug(exception, 'description')
        expect(notifier).to have_received(:report).with('debug', 'description', exception, nil)
        
        notifier.debug(exception, 'description', extra_data)
        expect(notifier).to have_received(:report).with('debug', 'description', exception, extra_data)
      end

      it 'should report with an info level' do
        notifier.info(exception)
        expect(notifier).to have_received(:report).with('info', nil, exception, nil)
        
        notifier.info(exception, 'description')
        expect(notifier).to have_received(:report).with('info', 'description', exception, nil)
        
        notifier.info(exception, 'description', extra_data)
        expect(notifier).to have_received(:report).with('info', 'description', exception, extra_data)
      end

      it 'should report with a warning level' do
        notifier.warning(exception)
        expect(notifier).to have_received(:report).with('warning', nil, exception, nil)
        
        notifier.warning(exception, 'description')
        expect(notifier).to have_received(:report).with('warning', 'description', exception, nil)
        
        notifier.warning(exception, 'description', extra_data)
        expect(notifier).to have_received(:report).with('warning', 'description', exception, extra_data)
      end

      it 'should report with an error level' do
        notifier.error(exception)
        expect(notifier).to have_received(:report).with('error', nil, exception, nil)
        
        notifier.error(exception, 'description')
        expect(notifier).to have_received(:report).with('error', 'description', exception, nil)
        
        notifier.error(exception, 'description', extra_data)
        expect(notifier).to have_received(:report).with('error', 'description', exception, extra_data)
      end

      it 'should report with a critical level' do
        notifier.critical(exception)
        expect(notifier).to have_received(:report).with('critical', nil, exception, nil)
        
        notifier.critical(exception, 'description')
        expect(notifier).to have_received(:report).with('critical', 'description', exception, nil)
        
        notifier.critical(exception, 'description', extra_data)
        expect(notifier).to have_received(:report).with('critical', 'description', exception, extra_data)
      end
    end
    
    context 'report' do
      let(:notifier) do
        notifier = Rollbar.scope
        notifier.stub(:schedule_payload)
        notifier
      end

      let(:logger_mock) { double("Rails.logger").as_null_object }
      
      before(:each) do
        configure
        Rollbar.configure do |config|
          config.logger = logger_mock
        end
      end
      
      after(:each) do
        Rollbar.unconfigure
        configure
      end
      
      it 'should reject input that doesn\'t contain an exception, message or extra data' do
        logger_mock.should_receive(:error).with('[Rollbar] Tried to send a report with no message, exception or extra data.')
        result = notifier.send(:report, 'info', nil, nil, nil)
        result.should == 'error'
        
        expect(notifier).to_not have_received(:schedule_payload)
      end
      
      it 'should be ignored if the person is ignored' do
        person_data = {
          :id => 1,
          :username => "test",
          :email => "test@example.com"
        }
        
        notifier.configure do |config|
          config.ignored_person_ids += [1]
          config.payload_options = {:person => person_data}
        end
        
        result = notifier.send(:report, 'info', 'message', nil, nil)
        result.should == 'ignored'
        
        expect(notifier).to_not have_received(:schedule_payload)
      end
      
      it 'should evaluate callables in the payload' do
        notifier.should receive(:schedule_payload) do |payload|
          data = MultiJson.decode(payload)["data"]
          
          data["body"]["message"]["extra"]["callable"].should == 2
        end
        
        notifier.send(:report, 'warning', 'message', nil, {:callable => lambda { 1 + 1 }})
      end
    end
    
    context 'build_payload' do
      let (:notifier) do
        notifier = Rollbar.scope
        notifier.stub(:report)
        notifier
      end
      
      after(:each) do
        Rollbar.unconfigure
        configure
      end
      
      context 'a basic payload' do
        let (:extra_data) { {:key => 'value', :hash => {:inner_key => 'inner_value'}} }
        let (:payload) { notifier.send(:build_payload, 'info', 'message', nil, extra_data) }
        
        it 'should have the correct root-level keys' do
          payload.should have_key :access_token
          payload.should have_key :data
        end
        
        it 'should have the correct data keys' do
          payload[:data].keys.should include(:timestamp, :environment, :level, :language, :framework, :server,
           :notifier, :body)
        end
        
        it 'should have the correct notifier name and version' do
          payload[:data][:notifier][:name].should == 'rollbar-gem'
          payload[:data][:notifier][:version].should == Rollbar::VERSION
        end
        
        it 'should have the correct language and framework' do
          payload[:data][:language].should == 'ruby'
          payload[:data][:framework].should == Rollbar.configuration.framework
          payload[:data][:framework].should match(/^Rails/)
        end
        
        it 'should have the correct server keys' do
          payload[:data][:server].keys.should include(:host, :root)
        end
        
        it 'should have the correct level and message body' do
          payload[:data][:level].should == 'info'
          payload[:data][:body][:message][:body].should == 'message'
        end
      end
    
      it 'should merge in a new key from payload_options' do
        notifier.configure do |config|
          config.payload_options = {:some_new_key => 'some new value'}
        end
        
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        
        payload[:data][:some_new_key].should == 'some new value'
      end
    
      it 'should overwrite existing keys from payload_options' do
        notifier.configure do |config|
          config.payload_options = {:notifier => 'bad notifier', :server => {:host => 'new host', :new_server_key => 'value'}}
        end
        
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        
        payload[:data][:notifier].should == 'bad notifier'
        payload[:data][:server][:host].should == 'new host'
        payload[:data][:server][:root].should_not be_nil
        payload[:data][:server][:new_server_key].should == 'value'
      end
      
      it 'should have default environment "unspecified"' do
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        payload[:data][:environment].should == 'unspecified'
      end

      it 'should have an overridden environment' do
        Rollbar.configure do |config|
          config.environment = 'overridden'
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        payload[:data][:environment].should == 'overridden'
      end

      it 'should not have custom data under default configuration' do
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        payload[:data][:body][:message][:extra].should be_nil
      end

      it 'should have custom message data when custom_data_method is configured' do
        Rollbar.configure do |config|
          config.custom_data_method = lambda { {:a => 1, :b => [2, 3, 4]} }
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        payload[:data][:body][:message][:extra].should_not be_nil
        payload[:data][:body][:message][:extra][:a].should == 1
        payload[:data][:body][:message][:extra][:b][2].should == 4
      end

      it 'should merge extra data into custom message data' do
        Rollbar.configure do |config|
          config.custom_data_method = lambda { {:a => 1, :b => [2, 3, 4], :c => {:d => 'd', :e => 'e'}, :f => ['1', '2']} }
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, {:c => {:e => 'g'}, :f => 'f'})
        payload[:data][:body][:message][:extra].should_not be_nil
        payload[:data][:body][:message][:extra][:a].should == 1
        payload[:data][:body][:message][:extra][:b][2].should == 4
        payload[:data][:body][:message][:extra][:c][:d].should == 'd'
        payload[:data][:body][:message][:extra][:c][:e].should == 'g'
        payload[:data][:body][:message][:extra][:f].should == 'f'
      end
      
      it 'should include project_gem_paths' do
        notifier.configure do |config|
          config.project_gems = ['rails', 'rspec']
        end
        
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        
        payload[:data][:project_package_paths].should have(2).items
      end
      
      it 'should include a code_version' do
        notifier.configure do |config|
          config.code_version = 'abcdef'
        end
        
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        
        payload[:data][:code_version].should == 'abcdef'
      end
      
      it 'should have the right hostname' do
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        
        payload[:data][:server][:host].should == Socket.gethostname
      end

      it 'should have root and branch set when configured' do
        configure
        Rollbar.configure do |config|
          config.root = '/path/to/root'
          config.branch = 'master'
        end
        
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)

        payload[:data][:server][:root].should == '/path/to/root'
        payload[:data][:server][:branch].should == 'master'
      end
    end
    
    context 'build_payload_body' do
      let(:exception) do
        begin
          foo = bar
        rescue => e
          e
        end
      end
      
      it 'should build a message body when no exception is passed in' do
        body = Rollbar.send(:build_payload_body, 'message', nil, nil)
        body[:message][:body].should == 'message'
        body[:message][:extra].should be_nil
        body[:trace].should be_nil
      end
      
      it 'should build a message body when no exception and extra data is passed in' do
        body = Rollbar.send(:build_payload_body, 'message', nil, {:a => 'b'})
        body[:message][:body].should == 'message'
        body[:message][:extra].should == {:a => 'b'}
        body[:trace].should be_nil
      end
      
      it 'should build an exception body when one is passed in' do
        body = Rollbar.send(:build_payload_body, 'message', exception, nil)
        body[:message].should be_nil

        trace = body[:trace]
        trace.should_not be_nil
        trace[:extra].should be_nil
        
        trace[:exception][:class].should_not be_nil
        trace[:exception][:message].should_not be_nil
      end
      
      it 'should build an exception body when one is passed in along with extra data' do
        body = Rollbar.send(:build_payload_body, 'message', exception, {:a => 'b'})
        body[:message].should be_nil

        trace = body[:trace]
        trace.should_not be_nil
        
        trace[:exception][:class].should_not be_nil
        trace[:exception][:message].should_not be_nil
        trace[:extra].should == {:a => 'b'}
      end
    end
    
    context 'build_payload_body_exception' do
      let (:notifier) do
        notifier = Rollbar.scope
        notifier.stub(:schedule_payload)
        notifier
      end
      
      let(:exception) do
        begin
          foo = bar
        rescue => e
          e
        end
      end
    
      after(:each) do
        Rollbar.unconfigure
        configure
      end

      it 'should build valid exception data' do
        body = Rollbar.send(:build_payload_body_exception, nil, exception, nil)
        body[:message].should be_nil

        trace = body[:trace]

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

      it 'should build exception data with a description' do
        body = Rollbar.send(:build_payload_body_exception, 'exception description', exception, nil)

        trace = body[:trace]

        trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
        trace[:exception][:description].should == 'exception description'
      end

      it 'should build exception data with a description and extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        body = Rollbar.send(:build_payload_body_exception, 'exception description', exception, extra_data)

        trace = body[:trace]

        trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
        trace[:exception][:description].should == 'exception description'
        trace[:extra][:key].should == 'value'
        trace[:extra][:hash].should == {:inner_key => 'inner_value'}
      end

      it 'should build exception data with a extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        body = Rollbar.send(:build_payload_body_exception, nil, exception, extra_data)

        trace = body[:trace]

        trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
        trace[:extra][:key].should == 'value'
        trace[:extra][:hash].should == {:inner_key => 'inner_value'}
      end
    end
    
    context 'build_payload_body_message' do
      it 'should build a message' do
        body = Rollbar.send(:build_payload_body_message, 'message', nil)
        body[:message][:body].should == 'message'
        body[:trace].should be_nil
      end
      
      it 'should build a message with extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        body = Rollbar.send(:build_payload_body_message, 'message', extra_data)
        body[:message][:body].should == 'message'
        body[:message][:extra][:key].should == 'value'
        body[:message][:extra][:hash].should == {:inner_key => 'inner_value'}
      end
      
      it 'should build an empty message with extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        body = Rollbar.send(:build_payload_body_message, nil, extra_data)
        body[:message][:body].should == 'Empty message'
        body[:message][:extra][:key].should == 'value'
        body[:message][:extra][:hash].should == {:inner_key => 'inner_value'}
      end
    end
    
    context 'get_payload_json' do
      let(:exception) do
        begin
          foo = bar
        rescue => e
          e
        end
      end
      
      let (:notifier) do
        notifier = Rollbar.scope
        notifier.stub(:report)
        notifier
      end
      
      before(:each) do
        configure
        Rollbar.configure do |config|
          config.logger = logger_mock
        end
      end
      
      after(:each) do
        Rollbar.unconfigure
        configure
      end

      let(:logger_mock) { double("Rails.logger").as_null_object }

      it 'should build valid json' do
        json = notifier.send(:get_payload_json, {:data => {:foo => {:bar => "baz"}}})
        hash = MultiJson.load(json)
        hash["data"]["foo"]["bar"].should == "baz"
      end
      
      it 'should strip out invalid utf-8' do
        json = notifier.send(:get_payload_json, {:data => {
          :good_key => "\255bad value",
          "bad\255 key" => "good value",
          "bad key 2\255" => "bad \255value",
          :hash => {
            "bad array \255key" => ["bad\255 array element", "good array element"]
          }
        }})
        
        hash = MultiJson.load(json)
        hash["data"]["good_key"].should == 'bad value'
        hash["data"]["bad key"].should == 'good value'
        hash["data"]["bad key 2"].should == 'bad value'
        hash["data"]["hash"].should == {
          "bad array key" => ["bad array element", "good array element"]
        }
      end

      it 'should truncate large strings if the payload is too big' do
        json = notifier.send(:get_payload_json, {:data => {:foo => {:bar => "baz"}, :large => 'a' * (128 * 1024), :small => 'b' * 1024}})
        hash = MultiJson.load(json)
        hash["data"]["large"].should == '%s...' % ('a' * 1021)
        hash["data"]["small"].should == 'b' * 1024
      end

      it 'should send a failsafe message if the payload cannot be reduced enough' do
        logger_mock.should_receive(:error).with(/Sending failsafe response due to Could not send payload due to it being too large after truncating attempts/)
        logger_mock.should_receive(:info).with('[Rollbar] Success')

        orig_max = Rollbar::MAX_PAYLOAD_SIZE

        Rollbar::MAX_PAYLOAD_SIZE = 1
        Rollbar.error(exception)

        Rollbar::MAX_PAYLOAD_SIZE = orig_max
      end
    end
    
    context 'enforce_valid_utf8' do
      let (:notifier) do
        notifier = Rollbar.scope
        notifier.stub(:report)
        notifier
      end
      
      it 'should replace invalid utf8 values' do
        payload = {
          :bad_value => "bad value 1\255",
          :bad_value_2 => "bad\255 value 2",
          "bad\255 key" => "good value",
          :hash => {
            :inner_bad_value => "\255\255bad value 3",
            "inner \255bad key" => 'inner good value',
            "bad array key\255" => [
              'good array value 1', 
              "bad\255 array value 1\255",
              {
                :inner_inner_bad => "bad inner \255inner value"
              }
            ]
          }
        }

        payload_copy = payload.clone
        notifier.send(:enforce_valid_utf8, payload_copy)
        
        payload_copy[:bad_value].should == "bad value 1"
        payload_copy[:bad_value_2].should == "bad value 2"
        payload_copy["bad key"].should == "good value"
        payload_copy.keys.should_not include("bad\456 key")
        payload_copy[:hash][:inner_bad_value].should == "bad value 3"
        payload_copy[:hash]["inner bad key"].should == 'inner good value'
        payload_copy[:hash]["bad array key"].should == [
          'good array value 1', 
          'bad array value 1', 
          {
            :inner_inner_bad => 'bad inner inner value'
          }
        ]
      end
    end

    context 'truncate_payload' do
      let (:notifier) do
        notifier = Rollbar.scope
        notifier.stub(:report)
        notifier
      end
      
      it 'should truncate all nested strings in the payload' do
        payload = {
          :truncated => '1234567',
          :not_truncated => '123456',
          :hash => {
            :inner_truncated => '123456789',
            :inner_not_truncated => '567',
            :array => ['12345678', '12', {:inner_inner => '123456789'}]
          }
        }

        payload_copy = payload.clone
        notifier.send(:truncate_payload, payload_copy, 6)

        payload_copy[:truncated].should == '123...'
        payload_copy[:not_truncated].should == '123456'
        payload_copy[:hash][:inner_truncated].should == '123...'
        payload_copy[:hash][:inner_not_truncated].should == '567'
        payload_copy[:hash][:array].should == ['123...', '12', {:inner_inner => '123...'}]
      end

      it 'should truncate utf8 strings properly' do
        payload = {
          :truncated => 'Ŝǻмρļẻ śţяịņģ',
          :not_truncated => '123456',
        }

        payload_copy = payload.clone
        notifier.send(:truncate_payload, payload_copy, 6)

        payload_copy[:truncated].should == "Ŝǻм..."
        payload_copy[:not_truncated].should == '123456'
      end
    end
  end
  
  context 'reporting' do
    let(:exception) do
      begin
        foo = bar
      rescue => e
        e
      end
    end
    
    let(:logger_mock) { double("Rails.logger").as_null_object }
    let(:user) { User.create(:email => 'email@example.com', :encrypted_password => '', :created_at => Time.now, :updated_at => Time.now) }
    
    before(:each) do
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
      end
    end
    
    after(:each) do
      Rollbar.unconfigure
      configure
    end
    
    it 'should report exceptions without person or request data' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.error(exception)
    end

    it 'should not report anything when disabled' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Success')
      
      Rollbar.configure do |config|
        config.enabled = false
      end

      Rollbar.error(exception).should == 'disabled'
    end
    
    it 'should report exceptions without person or request data' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.error(exception)
    end

    it 'should be enabled when freshly configured' do
      Rollbar.configuration.enabled.should == true
    end

    it 'should not be enabled when not configured' do
      Rollbar.unconfigure

      Rollbar.configuration.enabled.should be_nil
      Rollbar.error(exception).should == 'disabled'
    end

    it 'should stay disabled if configure is called again' do
      Rollbar.unconfigure

      # configure once, setting enabled to false.
      Rollbar.configure do |config|
        config.enabled = false
      end

      # now configure again (perhaps to change some other values)
      Rollbar.configure do |config| end

      Rollbar.configuration.enabled.should == false
      Rollbar.error(exception).should == 'disabled'
    end

    it 'should ignore ignored exception classes' do
      Rollbar.configure do |config|
        config.exception_level_filters = { 'NameError' => 'ignore' }
      end

      logger_mock.should_not_receive(:info)
      logger_mock.should_not_receive(:warn)
      logger_mock.should_not_receive(:error)

      Rollbar.error(exception)
    end

    it "should work with an IO object as rack.errors" do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      
      Rollbar.error(exception, :env => { :"rack.errors" => IO.new(2, File::WRONLY) })
    end

    it 'should ignore ignored persons' do
      person_data = {
        :id => 1,
        :username => "test",
        :email => "test@example.com"
      }
      
      Rollbar.configure do |config|
        config.payload_options = {:person => person_data}
        config.ignored_person_ids += [1]
      end

      logger_mock.should_not_receive(:info)
      logger_mock.should_not_receive(:warn)
      logger_mock.should_not_receive(:error)

      Rollbar.error(exception)
    end

    it 'should not ignore non-ignored persons' do
      person_data = {
        :id => 1,
        :username => "test",
        :email => "test@example.com"
      }
      Rollbar.configure do |config|
        config.payload_options = {:person => person_data}
        config.ignored_person_ids += [1]
      end

      Rollbar._last_report = nil

      Rollbar.error(exception)
      Rollbar._last_report.should be_nil

      person_data = {
        :id => 2,
        :username => "test2",
        :email => "test2@example.com"
      }
      
      Rollbar.configure do |config|
        config.payload_options = {:person => person_data}
      end
      
      Rollbar.error(exception)
      Rollbar._last_report.should_not be_nil
    end

    it 'should allow callables to set exception filtered level' do
      callable_mock = double
      saved_filters = Rollbar.configuration.exception_level_filters
      Rollbar.configure do |config|
        config.exception_level_filters = { 'NameError' => callable_mock }
      end

      callable_mock.should_receive(:call).with(exception).at_least(:once).and_return("info")
      logger_mock.should_receive(:info)
      logger_mock.should_not_receive(:warn)
      logger_mock.should_not_receive(:error)

      Rollbar.error(exception)
    end

    it 'should not report exceptions when silenced' do
      Rollbar._notifier.should_not_receive :schedule_payload

      begin
        test_var = 1
        Rollbar.silenced do
          test_var = 2
          raise
        end
      rescue => e
        Rollbar.error(e)
      end

      test_var.should == 2
    end

    it 'should report exception objects with no backtrace' do
      payload = nil
      Rollbar._notifier.stub(:schedule_payload) do |*args|
        payload = MultiJson.load(args[0])
      end
      Rollbar.error(StandardError.new("oops"))
      
      payload["data"]["body"]["trace"]["frames"].should == []
      payload["data"]["body"]["trace"]["exception"]["class"].should == "StandardError"
      payload["data"]["body"]["trace"]["exception"]["message"].should == "oops"
    end

    it 'should return the exception data with a uuid, on platforms with SecureRandom' do
      if defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)
        Rollbar.stub(:schedule_payload) do |*args| end
        exception_data = Rollbar.error(StandardError.new("oops"))
        exception_data[:uuid].should_not be_nil
      end
    end

    it 'should report exception objects with nonstandard backtraces' do
      payload = nil
      Rollbar._notifier.stub(:schedule_payload) do |*args|
        payload = MultiJson.load(args[0])
      end

      class CustomException < StandardError
        def backtrace
          ["custom backtrace line"]
        end
      end

      exception = CustomException.new("oops")

      Rollbar.error(exception)

      payload["data"]["body"]["trace"]["frames"][0]["method"].should == "custom backtrace line"
    end

    it 'should not crash with circular extra_data' do
      a = { :foo => "bar" }
      b = { :a => a }
      c = { :b => b }
      a[:c] = c

      logger_mock.should_receive(:error).with(/\[Rollbar\] Reporting internal error encountered while sending data to Rollbar./)

      Rollbar.error("Test message with circular extra data", a)
    end

    it 'should be able to report form validation errors when they are present' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      user.errors.add(:example, "error")
      user.report_validation_errors_to_rollbar
    end

    it 'should not report form validation errors when they are not present' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Success')
      user.errors.clear
      user.report_validation_errors_to_rollbar
    end

    it 'should report messages with extra data' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.info("Test message with extra data", :foo => "bar",
                               :hash => { :a => 123, :b => "xyz" })
    end

    it 'should report messages with request, person data and extra data' do
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling payload')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      request_data = {
        :params => {:foo => 'bar'}
      }

      person_data = {
        :id => 123,
        :username => 'username'
      }

      extra_data = {
        :extra_foo => 'extra_bar'
      }
      
      Rollbar.configure do |config|
        config.payload_options = {
          :request => request_data,
          :person => person_data
        }
      end

      Rollbar.info("Test message", extra_data)

      Rollbar._last_report[:request].should == request_data
      Rollbar._last_report[:person].should == person_data
      Rollbar._last_report[:body][:message][:extra][:extra_foo].should == 'extra_bar'
    end
  end

  context 'payload_destination' do
    before(:each) do
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
        config.filepath = 'test.rollbar'
      end
    end
    
    after(:each) do
      Rollbar.unconfigure
      configure
    end

    let(:exception) do
      begin
        foo = bar
      rescue => e
        e
      end
    end

    let(:logger_mock) { double("Rails.logger").as_null_object }

    it 'should send the payload over the network by default' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Writing payload to file')
      logger_mock.should_receive(:info).with('[Rollbar] Sending payload').once
      logger_mock.should_receive(:info).with('[Rollbar] Success').once
      Rollbar.error(exception)
    end

    it 'should save the payload to a file if set' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Sending payload')
      logger_mock.should_receive(:info).with('[Rollbar] Writing payload to file').once
      logger_mock.should_receive(:info).with('[Rollbar] Success').once

      filepath = ''

      Rollbar.configure do |config|
        config.write_to_file = true
        filepath = config.filepath
      end

      Rollbar.error(exception)

      File.exist?(filepath).should == true
      File.read(filepath).should include test_access_token
      File.delete(filepath)

      Rollbar.configure do |config|
        config.write_to_file = false
      end
    end
  end

  context 'asynchronous_handling' do
    before(:each) do
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
      end
    end
    
    after(:each) do
      Rollbar.unconfigure
      configure
    end

    let(:exception) do
      begin
        foo = bar
      rescue => e
        e
      end
    end
    
    let(:logger_mock) { double("Rails.logger").as_null_object }

    it 'should send the payload using the default asynchronous handler girl_friday' do
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling payload')
      logger_mock.should_receive(:info).with('[Rollbar] Sending payload')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      Rollbar.configure do |config|
        config.use_async = true
        GirlFriday::WorkQueue::immediate!
      end

      Rollbar.error(exception)

      Rollbar.configure do |config|
        config.use_async = false
        GirlFriday::WorkQueue::queue!
      end
    end

    it 'should send the payload using a user-supplied asynchronous handler' do
      logger_mock.should_receive(:info).with('Custom async handler called')
      logger_mock.should_receive(:info).with('[Rollbar] Sending payload')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      Rollbar.configure do |config|
        config.use_async = true
        config.async_handler = Proc.new { |payload|
          logger_mock.info 'Custom async handler called'
          Rollbar.process_payload(payload)
        }
      end

      Rollbar.error(exception)
    end

    describe "#use_sucker_punch", :if => defined?(SuckerPunch) do
      it "should send the payload to sucker_punch delayer" do
        logger_mock.should_receive(:info).with('[Rollbar] Scheduling payload')
        logger_mock.should_receive(:info).with('[Rollbar] Sending payload')
        logger_mock.should_receive(:info).with('[Rollbar] Success')

        Rollbar.configure do |config|
          config.use_sucker_punch
        end

        Rollbar.error(exception)
      end
    end

    describe "#use_sidekiq", :if => defined?(Sidekiq) do
      it "should instanciate sidekiq delayer with custom values" do
        Rollbar::Delay::Sidekiq.should_receive(:new).with('queue' => 'test_queue')
        config = Rollbar::Configuration.new
        config.use_sidekiq 'queue' => 'test_queue'
      end

      it "should send the payload to sidekiq delayer" do
        handler = double('sidekiq_handler_mock')
        handler.should_receive(:call)

        Rollbar.configure do |config|
          config.use_sidekiq
          config.async_handler = handler
        end

        Rollbar.error(exception)
      end
    end
  end

  context 'logger' do
    before(:each) do
      reset_configuration
    end

    it 'should have use the Rails logger when configured to do so' do
      configure
      Rollbar.send(:logger).should == ::Rails.logger
    end

    it 'should use the default_logger when no logger is set' do
      logger = Logger.new(STDERR)
      Rollbar.configure do |config|
        config.default_logger = lambda { logger }
      end
      Rollbar.send(:logger).should == logger
    end

    it 'should have a default default_logger' do
      Rollbar.send(:logger).should_not be_nil
    end

    after(:each) do
      reset_configuration
    end
  end

  context "project_gems" do
    it "should include gem paths for specified project gems in the payload" do
      gems = ['rack', 'rspec-rails']
      gem_paths = []

      Rollbar.configure do |config|
        config.project_gems = gems
      end

      gems.each {|gem|
        gem_paths.push(Gem::Specification.find_by_name(gem).gem_dir)
      }

      data = Rollbar.send(:build_payload, 'info', 'test', nil, {})[:data]
      data[:project_package_paths].kind_of?(Array).should == true
      data[:project_package_paths].length.should == gem_paths.length

      data[:project_package_paths].each_with_index{|path, index|
        path.should == gem_paths[index]
      }
    end

    it "should handle regex gem patterns" do
      gems = ["rack", /rspec/, /roll/]
      gem_paths = []

      Rollbar.configure do |config|
        config.project_gems = gems
      end

      gem_paths = gems.map{|gem| Gem::Specification.find_all_by_name(gem).map(&:gem_dir) }.flatten.compact.uniq
      gem_paths.length.should > 1
    
      gem_paths.any?{|path| path.include? 'rollbar-gem'}.should == true
      gem_paths.any?{|path| path.include? 'rspec-rails'}.should == true

      data = Rollbar.send(:build_payload, 'info', 'test', nil, {})[:data]
      data[:project_package_paths].kind_of?(Array).should == true
      data[:project_package_paths].length.should == gem_paths.length
      (data[:project_package_paths] - gem_paths).length.should == 0
    end

    it "should not break on non-existent gems" do
      gems = ["this_gem_does_not_exist", "rack"]

      Rollbar.configure do |config|
        config.project_gems = gems
      end

      data = Rollbar.send(:build_payload, 'info', 'test', nil, {})[:data]
      data[:project_package_paths].kind_of?(Array).should == true
      data[:project_package_paths].length.should == 1
    end
  end

  context "report_internal_error" do
    it "should not crash when given an exception object" do
      begin
        1 / 0
      rescue => e
        Rollbar.send(:report_internal_error, e)
      end
    end
  end

  context "send_failsafe" do
    it "should not crash when given a message and exception" do
      begin
        1 / 0
      rescue => e
        Rollbar.send(:send_failsafe, "test failsafe", e)
      end
    end

    it "should not crash when given all nils" do
      Rollbar.send(:send_failsafe, nil, nil)
    end
  end

  context "request_data_extractor" do
    before(:each) do
      class DummyClass
      end
      @dummy_class = DummyClass.new
      @dummy_class.extend(Rollbar::RequestDataExtractor)
    end

    context "rollbar_headers" do
      it "should not include cookies" do
        env = {"HTTP_USER_AGENT" => "test", "HTTP_COOKIE" => "cookie"}
        headers = @dummy_class.send(:rollbar_headers, env)
        headers.should have_key "User-Agent"
        headers.should_not have_key "Cookie"
      end
    end
  end

  # configure with some basic params
  def configure
    Rollbar.reconfigure do |config|
      # special test access token
      config.access_token = test_access_token
      config.logger = ::Rails.logger
      config.root = ::Rails.root
      config.framework = "Rails: #{::Rails::VERSION::STRING}"
      config.request_timeout = 60
    end
  end

  def test_access_token
    'aaaabbbbccccddddeeeeffff00001111'
  end

end
