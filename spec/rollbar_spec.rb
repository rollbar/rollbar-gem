# encoding: utf-8

require 'logger'
require 'socket'
require 'girl_friday'
require 'redis'
require 'active_support/core_ext/object'
require 'active_support/json/encoding'

begin
  require 'sucker_punch'
  require 'sucker_punch/testing/inline'
rescue LoadError
end

require 'spec_helper'

describe Rollbar do
  let(:notifier) { Rollbar.notifier }
  before do
    Rollbar.unconfigure
    configure
  end

  context 'when notifier has been used before configure it' do
    before do
      Rollbar.unconfigure
      Rollbar.reset_notifier!
    end

    it 'is finally reset' do
      Rollbar.log_debug('Testing notifier')
      expect(Rollbar.error('error message')).to be_eql('disabled')

      reconfigure_notifier

      expect(Rollbar.error('error message')).not_to be_eql('disabled')
    end
  end

  context 'Notifier' do
    context 'log' do
      let(:exception) do
        begin
          foo = bar
        rescue => e
          e
        end
      end

      let(:configuration) { Rollbar.configuration }

      context 'executing a Thread before Rollbar is configured', :skip_dummy_rollbar => true do
        before do
          Rollbar.reset_notifier!
          Rollbar.unconfigure

          Thread.new {}

          Rollbar.configure do |config|
            config.access_token = 'my-access-token'
          end
        end

        it 'sets correct configuration for Rollbar.notifier' do
          expect(Rollbar.notifier.configuration.enabled).to be_truthy
        end
      end

      it 'should report a simple message' do
        expect(notifier).to receive(:report).with('error', 'test message', nil, nil)
        notifier.log('error', 'test message')
      end

      it 'should report a simple message with extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}

        expect(notifier).to receive(:report).with('error', 'test message', nil, extra_data)
        notifier.log('error', 'test message', extra_data)
      end

      it 'should report an exception' do
        expect(notifier).to receive(:report).with('error', nil, exception, nil)
        notifier.log('error', exception)
      end

      it 'should report an exception with extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}

        expect(notifier).to receive(:report).with('error', nil, exception, extra_data)
        notifier.log('error', exception, extra_data)
      end

      it 'should report an exception with a description' do
        expect(notifier).to receive(:report).with('error', 'exception description', exception, nil)
        notifier.log('error', exception, 'exception description')
      end

      it 'should report an exception with a description and extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}

        expect(notifier).to receive(:report).with('error', 'exception description', exception, extra_data)
        notifier.log('error', exception, extra_data, 'exception description')
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

      let(:extra_data) { {:key => 'value', :hash => {:inner_key => 'inner_value'}} }

      it 'should report with a debug level' do
        expect(notifier).to receive(:report).with('debug', nil, exception, nil)
        notifier.debug(exception)

        expect(notifier).to receive(:report).with('debug', 'description', exception, nil)
        notifier.debug(exception, 'description')

        expect(notifier).to receive(:report).with('debug', 'description', exception, extra_data)
        notifier.debug(exception, 'description', extra_data)
      end

      it 'should report with an info level' do
        expect(notifier).to receive(:report).with('info', nil, exception, nil)
        notifier.info(exception)

        expect(notifier).to receive(:report).with('info', 'description', exception, nil)
        notifier.info(exception, 'description')

        expect(notifier).to receive(:report).with('info', 'description', exception, extra_data)
        notifier.info(exception, 'description', extra_data)
      end

      it 'should report with a warning level' do
        expect(notifier).to receive(:report).with('warning', nil, exception, nil)
        notifier.warning(exception)

        expect(notifier).to receive(:report).with('warning', 'description', exception, nil)
        notifier.warning(exception, 'description')

        expect(notifier).to receive(:report).with('warning', 'description', exception, extra_data)
        notifier.warning(exception, 'description', extra_data)
      end

      it 'should report with an error level' do
        expect(notifier).to receive(:report).with('error', nil, exception, nil)
        notifier.error(exception)

        expect(notifier).to receive(:report).with('error', 'description', exception, nil)
        notifier.error(exception, 'description')

        expect(notifier).to receive(:report).with('error', 'description', exception, extra_data)
        notifier.error(exception, 'description', extra_data)
      end

      it 'should report with a critical level' do
        expect(notifier).to receive(:report).with('critical', nil, exception, nil)
        notifier.critical(exception)

        expect(notifier).to receive(:report).with('critical', 'description', exception, nil)
        notifier.critical(exception, 'description')

        expect(notifier).to receive(:report).with('critical', 'description', exception, extra_data)
        notifier.critical(exception, 'description', extra_data)
      end
    end

    context 'scope' do
      it 'should create a new notifier object' do
        notifier2 = notifier.scope

        notifier2.should_not eq(notifier)
        notifier2.should be_instance_of(Rollbar::Notifier)
      end

      it 'should create a copy of the parent notifier\'s configuration' do
        notifier.configure do |config|
          config.code_version = '123'
          config.payload_options = {
            :a => 'a',
            :b => {:c => 'c'}
          }
        end

        notifier2 = notifier.scope

        notifier2.configuration.code_version.should == '123'
        notifier2.configuration.should_not equal(notifier.configuration)
        notifier2.configuration.payload_options.should_not equal(notifier.configuration.payload_options)
        notifier2.configuration.payload_options.should == notifier.configuration.payload_options
        notifier2.configuration.payload_options.should == {
          :a => 'a',
          :b => {:c => 'c'}
        }
      end

      it 'should not modify any parent notifier configuration' do
        configure
        Rollbar.configuration.code_version.should be_nil
        Rollbar.configuration.payload_options.should be_empty

        notifier.configure do |config|
          config.code_version = '123'
          config.payload_options = {
            :a => 'a',
            :b => {:c => 'c'}
          }
        end

        notifier2 = notifier.scope

        notifier2.configure do |config|
          config.payload_options[:c] = 'c'
        end

        notifier.configuration.payload_options[:c].should be_nil

        notifier3 = notifier2.scope({
          :b => {:c => 3, :d => 'd'}
        })

        notifier3.configure do |config|
          config.code_version = '456'
        end

        notifier.configuration.code_version.should == '123'
        notifier.configuration.payload_options.should == {
          :a => 'a',
          :b => {:c => 'c'}
        }
        notifier2.configuration.code_version.should == '123'
        notifier2.configuration.payload_options.should == {
          :a => 'a',
          :b => {:c => 'c'},
          :c => 'c'
        }
        notifier3.configuration.code_version.should == '456'
        notifier3.configuration.payload_options.should == {
          :a => 'a',
          :b => {:c => 3, :d => 'd'},
          :c => 'c'
        }

        Rollbar.configuration.code_version.should be_nil
        Rollbar.configuration.payload_options.should be_empty
      end
    end

    context 'report' do
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
        expect(logger_mock).to receive(:error).with('[Rollbar] Tried to send a report with no message, exception or extra data.')
        expect(notifier).not_to receive(:schedule_payload)

        result = notifier.send(:report, 'info', nil, nil, nil)
        result.should == 'error'
      end

      it 'should be ignored if the person is ignored' do
        person_data = {
          :id => 1,
          :username => "test",
          :email => "test@example.com"
        }

        notifier.configure do |config|
          config.ignored_person_ids += [1]
          config.payload_options = { :person => person_data }
        end

        expect(notifier).not_to receive(:schedule_payload)

        result = notifier.send(:report, 'info', 'message', nil, nil)
        result.should == 'ignored'
      end
    end

    context 'build_payload' do
      context 'a basic payload' do
        let(:extra_data) { {:key => 'value', :hash => {:inner_key => 'inner_value'}} }
        let(:payload) { notifier.send(:build_payload, 'info', 'message', nil, extra_data) }

        it 'should have the correct root-level keys' do
          payload.keys.should match_array(['access_token', 'data'])
        end

        it 'should have the correct data keys' do
          payload['data'].keys.should include(:timestamp, :environment, :level, :language, :framework, :server,
            :notifier, :body)
        end

        it 'should have the correct notifier name and version' do
          payload['data'][:notifier][:name].should == 'rollbar-gem'
          payload['data'][:notifier][:version].should == Rollbar::VERSION
        end

        it 'should have the correct language and framework' do
          payload['data'][:language].should == 'ruby'
          payload['data'][:framework].should == Rollbar.configuration.framework
          payload['data'][:framework].should match(/^Rails/)
        end

        it 'should have the correct server keys' do
          payload['data'][:server].keys.should match_array([:host, :root, :pid])
        end

        it 'should have the correct level and message body' do
          payload['data'][:level].should == 'info'
          payload['data'][:body][:message][:body].should == 'message'
        end
      end

      it 'should merge in a new key from payload_options' do
        notifier.configure do |config|
          config.payload_options = { :some_new_key => 'some new value' }
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)

        payload['data'][:some_new_key].should == 'some new value'
      end

      it 'should overwrite existing keys from payload_options' do
        reconfigure_notifier

        payload_options = {
          :notifier => 'bad notifier',
          :server => { :host => 'new host', :new_server_key => 'value' }
        }

        notifier.configure do |config|
          config.payload_options = payload_options
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)

        payload['data'][:notifier].should == 'bad notifier'
        payload['data'][:server][:host].should == 'new host'
        payload['data'][:server][:root].should_not be_nil
        payload['data'][:server][:new_server_key].should == 'value'
      end

      it 'should have default environment "unspecified"' do
        Rollbar.unconfigure
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        payload['data'][:environment].should == 'unspecified'
      end

      it 'should have an overridden environment' do
        Rollbar.configure do |config|
          config.environment = 'overridden'
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        payload['data'][:environment].should == 'overridden'
      end

      it 'should not have custom data under default configuration' do
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        payload['data'][:body][:message][:extra].should be_nil
      end

      it 'should have custom message data when custom_data_method is configured' do
        Rollbar.configure do |config|
          config.custom_data_method = lambda { {:a => 1, :b => [2, 3, 4]} }
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)
        payload['data'][:body][:message][:extra].should_not be_nil
        payload['data'][:body][:message][:extra][:a].should == 1
        payload['data'][:body][:message][:extra][:b][2].should == 4
      end

      it 'should merge extra data into custom message data' do
        custom_method = lambda do
          { :a => 1,
            :b => [2, 3, 4],
            :c => { :d => 'd', :e => 'e' },
            :f => ['1', '2']
          }
        end

        Rollbar.configure do |config|
          config.custom_data_method = custom_method
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, {:c => {:e => 'g'}, :f => 'f'})
        payload['data'][:body][:message][:extra].should_not be_nil
        payload['data'][:body][:message][:extra][:a].should == 1
        payload['data'][:body][:message][:extra][:b][2].should == 4
        payload['data'][:body][:message][:extra][:c][:d].should == 'd'
        payload['data'][:body][:message][:extra][:c][:e].should == 'g'
        payload['data'][:body][:message][:extra][:f].should == 'f'
      end

      context 'with custom_data_method crashing' do
        next unless defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)

        let(:crashing_exception) { StandardError.new }
        let(:custom_method) { proc { raise crashing_exception } }
        let(:extra) { { :foo => :bar } }
        let(:custom_data_report) do
          { :_error_in_custom_data_method => SecureRandom.uuid }
        end
        let(:expected_extra) { extra.merge(custom_data_report) }

        before do
          notifier.configure do |config|
            config.custom_data_method = custom_method
          end
        end

        it 'doesnt crash the report' do
          expect(notifier).to receive(:report_custom_data_error).once.and_return(custom_data_report)
          payload = notifier.send(:build_payload, 'info', 'message', nil, extra)

          expect(payload['data'][:body][:message][:extra]).to be_eql(expected_extra)
        end

        context 'and for some reason the safely.error returns a String' do
          it 'returns an empty Hash' do
            allow_any_instance_of(Rollbar::Notifier).to receive(:error).and_return('ignored')

            payload = notifier.send(:build_payload, 'info', 'message', nil, extra)

            expect(payload['data'][:body][:message][:extra]).to be_eql(extra)
          end
        end
      end

      it 'should include project_gem_paths' do
        notifier.configure do |config|
          config.project_gems = ['rails', 'rspec']
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)

        expect(payload['data'][:project_package_paths].count).to eq 2
      end

      it 'should include a code_version' do
        notifier.configure do |config|
          config.code_version = 'abcdef'
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)

        payload['data'][:code_version].should == 'abcdef'
      end

      it 'should have the right hostname' do
        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)

        payload['data'][:server][:host].should == Socket.gethostname
      end

      it 'should have root and branch set when configured' do
        configure
        Rollbar.configure do |config|
          config.root = '/path/to/root'
          config.branch = 'master'
        end

        payload = notifier.send(:build_payload, 'info', 'message', nil, nil)

        payload['data'][:server][:root].should == '/path/to/root'
        payload['data'][:server][:branch].should == 'master'
      end

      context "with Redis instance in payload and ActiveSupport is enabled" do
        let(:redis) { ::Redis.new }
        let(:payload) do
          {
            :key => {
              :value => redis
            }
          }
        end
        it 'dumps to JSON correctly' do
          redis.set('foo', 'bar')
          json = notifier.send(:dump_payload, payload)

          expect(json).to be_kind_of(String)
        end
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
        body = notifier.send(:build_payload_body, 'message', nil, nil)
        body[:message][:body].should == 'message'
        body[:message][:extra].should be_nil
        body[:trace].should be_nil
      end

      it 'should build a message body when no exception and extra data is passed in' do
        body = notifier.send(:build_payload_body, 'message', nil, {:a => 'b'})
        body[:message][:body].should == 'message'
        body[:message][:extra].should == {:a => 'b'}
        body[:trace].should be_nil
      end

      it 'should build an exception body when one is passed in' do
        body = notifier.send(:build_payload_body, 'message', exception, nil)
        body[:message].should be_nil

        trace = body[:trace]
        trace.should_not be_nil
        trace[:extra].should be_nil

        trace[:exception][:class].should_not be_nil
        trace[:exception][:message].should_not be_nil
      end

      it 'should build an exception body when one is passed in along with extra data' do
        body = notifier.send(:build_payload_body, 'message', exception, {:a => 'b'})
        body[:message].should be_nil

        trace = body[:trace]
        trace.should_not be_nil

        trace[:exception][:class].should_not be_nil
        trace[:exception][:message].should_not be_nil
        trace[:extra].should == {:a => 'b'}
      end
    end

    context 'build_payload_body_exception' do
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
        body = notifier.send(:build_payload_body_exception, nil, exception, nil)
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
        body = notifier.send(:build_payload_body_exception, 'exception description', exception, nil)

        trace = body[:trace]

        trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
        trace[:exception][:description].should == 'exception description'
      end

      it 'should build exception data with a description and extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        body = notifier.send(:build_payload_body_exception, 'exception description', exception, extra_data)

        trace = body[:trace]

        trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
        trace[:exception][:description].should == 'exception description'
        trace[:extra][:key].should == 'value'
        trace[:extra][:hash].should == {:inner_key => 'inner_value'}
      end

      it 'should build exception data with a extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        body = notifier.send(:build_payload_body_exception, nil, exception, extra_data)

        trace = body[:trace]

        trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
        trace[:extra][:key].should == 'value'
        trace[:extra][:hash].should == {:inner_key => 'inner_value'}
      end

      context 'with nested exceptions' do
        let(:crashing_code) do
          proc do
            begin
              begin
                fail CauseException.new('the cause')
              rescue
                fail StandardError.new('the error')
              end
            rescue => e
              e
            end
          end
        end

        let(:rescued_exception) { crashing_code.call }
        let(:message) { 'message' }
        let(:extra) { {} }

        context 'using ruby >= 2.1' do
          next unless Exception.instance_methods.include?(:cause)

          it 'sends the two exceptions in the trace_chain attribute' do
            body = notifier.send(:build_payload_body_exception, message, rescued_exception, extra)

            body[:trace].should be_nil
            body[:trace_chain].should be_kind_of(Array)

            chain = body[:trace_chain]
            chain[0][:exception][:class].should match(/StandardError/)
            chain[0][:exception][:message].should match(/the error/)

            chain[1][:exception][:class].should match(/CauseException/)
            chain[1][:exception][:message].should match(/the cause/)
          end

          it 'ignores the cause when it is not an Exception' do
            exception_with_custom_cause = Exception.new('custom cause')
            allow(exception_with_custom_cause).to receive(:cause) { "Foo" }
            body = notifier.send(:build_payload_body_exception, message, exception_with_custom_cause, extra)
            body[:trace].should_not be_nil
          end

          context 'with cyclic nested exceptions' do
            let(:exception1) { Exception.new('exception1') }
            let(:exception2) { Exception.new('exception2') }

            before do
              allow(exception1).to receive(:cause).and_return(exception2)
              allow(exception2).to receive(:cause).and_return(exception1)
            end

            it 'doesnt loop for ever' do
              body = notifier.send(:build_payload_body_exception, message, exception1, extra)
              chain = body[:trace_chain]

              expect(chain[0][:exception][:message]).to be_eql('exception1')
              expect(chain[1][:exception][:message]).to be_eql('exception2')
            end
          end
        end

        context 'using ruby <= 2.1' do
          next if Exception.instance_methods.include?(:cause)

          it 'sends only the last exception in the trace attribute' do
            body = notifier.send(:build_payload_body_exception, message, rescued_exception, extra)

            body[:trace].should be_kind_of(Hash)
            body[:trace_chain].should be_nil

            body[:trace][:exception][:class].should match(/StandardError/)
            body[:trace][:exception][:message].should match(/the error/)
          end
        end
      end
    end

    context 'build_payload_body_message' do
      it 'should build a message' do
        body = notifier.send(:build_payload_body_message, 'message', nil)
        body[:message][:body].should == 'message'
        body[:trace].should be_nil
      end

      it 'should build a message with extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        body = notifier.send(:build_payload_body_message, 'message', extra_data)
        body[:message][:body].should == 'message'
        body[:message][:extra][:key].should == 'value'
        body[:message][:extra][:hash].should == {:inner_key => 'inner_value'}
      end

      it 'should build an empty message with extra data' do
        extra_data = {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        body = notifier.send(:build_payload_body_message, nil, extra_data)
        body[:message][:body].should == 'Empty message'
        body[:message][:extra][:key].should == 'value'
        body[:message][:extra][:hash].should == {:inner_key => 'inner_value'}
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

    context 'using :use_exception_level_filters option as true' do
      it 'sends the correct filtered level' do
        Rollbar.configure do |config|
          config.exception_level_filters = { 'NameError' => 'warning' }
        end

        Rollbar.error(exception, :use_exception_level_filters => true)
        expect(Rollbar.last_report[:level]).to be_eql('warning')
      end

      it 'ignore ignored exception classes' do
        Rollbar.configure do |config|
          config.exception_level_filters = { 'NameError' => 'ignore' }
        end

        logger_mock.should_not_receive(:info)
        logger_mock.should_not_receive(:warn)
        logger_mock.should_not_receive(:error)

        Rollbar.error(exception, :use_exception_level_filters => true)
      end
    end

    context 'if not using :use_exception_level_filters option' do
      it 'sends the level defined by the used method' do
        Rollbar.configure do |config|
          config.exception_level_filters = { 'NameError' => 'warning' }
        end

        Rollbar.error(exception)
        expect(Rollbar.last_report[:level]).to be_eql('error')
      end

      it 'ignore ignored exception classes' do
        Rollbar.configure do |config|
          config.exception_level_filters = { 'NameError' => 'ignore' }
        end

        Rollbar.error(exception)

        expect(Rollbar.last_report[:level]).to be_eql('error')
      end
    end

    # Skip jruby 1.9+ (https://github.com/jruby/jruby/issues/2373)
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby' && (not RUBY_VERSION =~ /^1\.9/)
      it "should work with an IO object as rack.errors" do
        logger_mock.should_receive(:info).with('[Rollbar] Success')

        Rollbar.error(exception, :env => { :"rack.errors" => IO.new(2, File::WRONLY) })
      end
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
        config.payload_options = { :person => person_data }
        config.ignored_person_ids += [1]
      end

      Rollbar.last_report = nil

      Rollbar.error(exception)
      Rollbar.last_report.should be_nil

      person_data = {
        :id => 2,
        :username => "test2",
        :email => "test2@example.com"
      }

      new_options = {
        :person => person_data
      }

      Rollbar.scoped(new_options) do
        Rollbar.error(exception)
      end

      Rollbar.last_report.should_not be_nil
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

      Rollbar.error(exception, :use_exception_level_filters => true)
    end

    it 'should not report exceptions when silenced' do
      expect_any_instance_of(Rollbar::Notifier).to_not receive(:schedule_payload)

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

      notifier.stub(:schedule_payload) do |*args|
        payload = args[0]
      end

      Rollbar.error(StandardError.new("oops"))

      payload["data"][:body][:trace][:frames].should == []
      payload["data"][:body][:trace][:exception][:class].should == "StandardError"
      payload["data"][:body][:trace][:exception][:message].should == "oops"
    end

    it 'gets the backtrace from the caller' do
      Rollbar.configure do |config|
        config.populate_empty_backtraces = true
      end

      exception = Exception.new

      Rollbar.error(exception)

      gem_dir = Gem::Specification.find_by_name('rollbar').gem_dir
      gem_lib_dir = gem_dir + '/lib'
      last_report = Rollbar.last_report

      filepaths = last_report[:body][:trace][:frames].map {|frame| frame[:filename] }.reverse

      expect(filepaths[0]).not_to include(gem_lib_dir)
      expect(filepaths.any? {|filepath| filepath.include?(gem_dir) }).to eq true
    end

    it 'should return the exception data with a uuid, on platforms with SecureRandom' do
      if defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)
        exception_data = Rollbar.error(StandardError.new("oops"))
        exception_data[:uuid].should_not be_nil
      end
    end

    it 'should report exception objects with nonstandard backtraces' do
      payload = nil

      notifier.stub(:schedule_payload) do |*args|
        payload = args[0]
      end

      class CustomException < StandardError
        def backtrace
          ["custom backtrace line"]
        end
      end

      exception = CustomException.new("oops")

      notifier.error(exception)

      payload["data"][:body][:trace][:frames][0][:method].should == "custom backtrace line"
    end

    it 'should report exceptions with a custom level' do
      payload = nil

      notifier.stub(:schedule_payload) do |*args|
        payload = args[0]
      end

      Rollbar.error(exception)

      payload['data'][:level].should == 'error'

      Rollbar.log('debug', exception)

      payload['data'][:level].should == 'debug'
    end

    context 'with invalid utf8 encoding' do
      let(:extra) do
        { :extra => force_to_ascii("bad value 1\255") }
      end

      it 'removes te invalid characteres' do
        Rollbar.info('removing invalid chars', extra)

        extra_value = Rollbar.last_report[:body][:message][:extra][:extra]
        expect(extra_value).to be_eql('bad value 1')
      end
    end
  end

  # Backwards
  context 'report_message' do
    before(:each) do
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
      end
    end

    let(:logger_mock) { double("Rails.logger").as_null_object }
    let(:user) { User.create(:email => 'email@example.com', :encrypted_password => '', :created_at => Time.now, :updated_at => Time.now) }

    it 'should report simple messages' do
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling payload')
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.error('Test message')
    end

    it 'should not report anything when disabled' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Success')
      Rollbar.configure do |config|
        config.enabled = false
      end

      Rollbar.error('Test message that should be ignored')

      Rollbar.configure do |config|
        config.enabled = true
      end
    end

    it 'should report messages with extra data' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.debug('Test message with extra data', 'debug', :foo => "bar",
                                                             :hash => { :a => 123, :b => "xyz" })
    end

    # END Backwards

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

      Rollbar.last_report[:request].should == request_data
      Rollbar.last_report[:person].should == person_data
      Rollbar.last_report[:body][:message][:extra][:extra_foo].should == 'extra_bar'
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
        GirlFriday::WorkQueue.immediate!
      end

      Rollbar.error(exception)

      Rollbar.configure do |config|
        config.use_async = false
        GirlFriday::WorkQueue.queue!
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

    # We should be able to send String payloads, generated
    # by a previous version of the gem. This can happend just
    # after a deploy with an gem upgrade.
    context 'with a payload generated as String' do
      let(:async_handler) do
        proc do |payload|
          # simulate previous gem version
          string_payload = Rollbar::JSON.dump(payload)

          Rollbar.process_payload(string_payload)
        end
      end

      before do
        Rollbar.configuration.stub(:use_async).and_return(true)
        Rollbar.configuration.stub(:async_handler).and_return(async_handler)
      end

      it 'sends a payload generated as String, not as a Hash' do
        logger_mock.should_receive(:info).with('[Rollbar] Success')

        Rollbar.error(exception)
      end

      context 'with async failover handlers' do
        before do
          Rollbar.reconfigure do |config|
            config.use_async = true
            config.async_handler = async_handler
            config.failover_handlers = handlers
            config.logger = logger_mock
          end
        end

        let(:exception) { StandardError.new('the error') }

        context 'if the async handler doesnt fail' do
          let(:async_handler) { proc { |_| 'success' } }
          let(:handler) { proc { |_| 'success' } }
          let(:handlers) { [handler] }

          it 'doesnt call any failover handler' do
            expect(handler).not_to receive(:call)

            Rollbar.error(exception)
          end
        end

        context 'if the async handler fails' do
          let(:async_handler) { proc { |_| fail 'this handler will crash' } }

          context 'if any failover handlers is configured' do
            let(:handlers) { [] }
            let(:log_message) do
              '[Rollbar] Async handler failed, and there are no failover handlers configured. See the docs for "failover_handlers"'
            end

            it 'logs the error but doesnt try to report an internal error' do
              expect(logger_mock).to receive(:error).with(log_message)

              Rollbar.error(exception)
            end
          end

          context 'if the first failover handler success' do
            let(:handler) { proc { |_| 'success' } }
            let(:handlers) { [handler] }

            it 'calls the failover handler and doesnt report internal error' do
              expect(Rollbar).not_to receive(:report_internal_error)
              expect(handler).to receive(:call)

              Rollbar.error(exception)
            end
          end

          context 'with two handlers, the first failing' do
            let(:handler1) { proc { |_| fail 'this handler fails' } }
            let(:handler2) { proc { |_| 'success' } }
            let(:handlers) { [handler1, handler2] }

            it 'calls the second handler and doesnt report internal error' do
              expect(handler2).to receive(:call)

              Rollbar.error(exception)
            end
          end

          context 'with two handlers, both failing' do
            let(:handler1) { proc { |_| fail 'this handler fails' } }
            let(:handler2) { proc { |_| fail 'this will also fail' } }
            let(:handlers) { [handler1, handler2] }

            it 'reports internal error' do
              expect(logger_mock).to receive(:error)

              Rollbar.error(exception)
            end
          end
        end
      end
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
      expect(Rollbar.send(:logger)).to be_kind_of(Rollbar::LoggerProxy)
      expect(Rollbar.send(:logger).object).to eq ::Rails.logger
    end

    it 'should use the default_logger when no logger is set' do
      logger = Logger.new(STDERR)

      Rollbar.configure do |config|
        config.default_logger = lambda { logger }
      end

      Rollbar.send(:logger).object.should == logger
    end

    it 'should have a default default_logger' do
      Rollbar.send(:logger).should_not be_nil
    end

    after(:each) do
      reset_configuration
    end
  end

  context 'enforce_valid_utf8' do
    # TODO(jon): all these tests should be removed since they are in
    # in spec/rollbar/encoding/encoder.rb.
    #
    # This should just check that in payload with simple values and
    # nested values are each one passed through Rollbar::Encoding.encode
    context 'with utf8 string and ruby > 1.8' do
      next unless String.instance_methods.include?(:force_encoding)

      let(:payload) { { :foo => 'Изменение' } }

      it 'just returns the same string' do
        payload_copy = payload.clone
        notifier.send(:enforce_valid_utf8, payload_copy)

        expect(payload_copy[:foo]).to be_eql('Изменение')
      end
    end

    it 'should replace invalid utf8 values' do
      bad_key = force_to_ascii("inner \x92bad key")

      payload = {
        :bad_value => force_to_ascii("bad value 1\255"),
        :bad_value_2 => force_to_ascii("bad\255 value 2"),
        force_to_ascii("bad\255 key") => "good value",
        :hash => {
          :inner_bad_value => force_to_ascii("\255\255bad value 3"),
          bad_key.to_sym => 'inner good value',
          force_to_ascii("bad array key\255") => [
            'good array value 1',
            force_to_ascii("bad\255 array value 1\255"),
            {
              :inner_inner_bad => force_to_ascii("bad inner \255inner value")
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
      payload_copy[:hash][:"inner bad key"].should == 'inner good value'
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

  context 'server_data' do
    it 'should have the right hostname' do
      notifier.send(:server_data)[:host] == Socket.gethostname
    end

    it 'should have root and branch set when configured' do
      configure
      Rollbar.configure do |config|
        config.root = '/path/to/root'
        config.branch = 'master'
      end

      data = notifier.send(:server_data)
      data[:root].should == '/path/to/root'
      data[:branch].should == 'master'
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

      data = notifier.send(:build_payload, 'info', 'test', nil, {})['data']
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

      data = notifier.send(:build_payload, 'info', 'test', nil, {})['data']
      data[:project_package_paths].kind_of?(Array).should == true
      data[:project_package_paths].length.should == gem_paths.length
      (data[:project_package_paths] - gem_paths).length.should == 0
    end

    it "should not break on non-existent gems" do
      gems = ["this_gem_does_not_exist", "rack"]

      Rollbar.configure do |config|
        config.project_gems = gems
      end

      data = notifier.send(:build_payload, 'info', 'test', nil, {})['data']
      data[:project_package_paths].kind_of?(Array).should == true
      data[:project_package_paths].length.should == 1
    end
  end

  context 'report_internal_error', :reconfigure_notifier => true do
    it "should not crash when given an exception object" do
      begin
        1 / 0
      rescue => e
        notifier.send(:report_internal_error, e)
      end
    end
  end

  context "send_failsafe" do
    let(:exception) { StandardError.new }

    it "doesn't crash when given a message and exception" do
      sent_payload = notifier.send(:send_failsafe, "test failsafe", exception)

      expected_message = 'Failsafe from rollbar-gem. StandardError: test failsafe'
      expect(sent_payload['data'][:body][:message][:body]).to be_eql(expected_message)
    end

    it "doesn't crash when given all nils" do
      notifier.send(:send_failsafe, nil, nil)
    end

    context 'with a non default exception message' do
      let(:exception) { StandardError.new 'Something is wrong' }

      it 'adds it to exception info' do
        sent_payload = notifier.send(:send_failsafe, "test failsafe", exception)

        expected_message = 'Failsafe from rollbar-gem. StandardError: "Something is wrong": test failsafe'
        expect(sent_payload['data'][:body][:message][:body]).to be_eql(expected_message)
      end
    end

    context 'without exception object' do
      it 'just sends the given message' do
        sent_payload = notifier.send(:send_failsafe, "test failsafe", nil)

        expected_message = 'Failsafe from rollbar-gem. test failsafe'
        expect(sent_payload['data'][:body][:message][:body]).to be_eql(expected_message)
      end
    end

    context 'if the exception has a backtrace' do
      let(:backtrace) { ['func3', 'func2', 'func1'] }
      let(:failsafe_reason) { 'StandardError in func3: test failsafe' }
      let(:expected_body) { "Failsafe from rollbar-gem. #{failsafe_reason}" }
      let(:expected_log_message) do
        "[Rollbar] Sending failsafe response due to #{failsafe_reason}"
      end

      before { exception.set_backtrace(backtrace) }

      it 'adds the nearest frame to the message' do
        expect(notifier).to receive(:log_error).with(expected_log_message)

        sent_payload = notifier.send(:send_failsafe, "test failsafe", exception)

        expect(sent_payload['data'][:body][:message][:body]).to be_eql(expected_body)
      end
    end
  end

  context 'when reporting internal error with nil context' do
    let(:context_proc) { proc {} }
    let(:scoped_notifier) { notifier.scope(:context => context_proc) }
    let(:exception) { Exception.new }
    let(:logger_mock) { double("Rails.logger").as_null_object }

    it 'reports successfully' do
      configure

      Rollbar.configure do |config|
        config.logger = logger_mock
      end

      logger_mock.should_receive(:info).with('[Rollbar] Sending payload').once
      logger_mock.should_receive(:info).with('[Rollbar] Success').once
      scoped_notifier.send(:report_internal_error, exception)
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

  describe '.scoped' do
    let(:scope_options) do
      { :foo => 'bar' }
    end

    it 'changes payload options inside the block' do
      Rollbar.reset_notifier!
      configure

      current_notifier_id = Rollbar.notifier.object_id

      Rollbar.scoped(scope_options) do
        configuration = Rollbar.notifier.configuration

        expect(Rollbar.notifier.object_id).not_to be_eql(current_notifier_id)
        expect(configuration.payload_options).to be_eql(scope_options)
      end

      expect(Rollbar.notifier.object_id).to be_eql(current_notifier_id)
    end

    context 'if the block fails' do
      let(:crashing_block) { proc { fail } }

      it 'restores the old notifier' do
        notifier = Rollbar.notifier

        expect { Rollbar.scoped(&crashing_block) }.to raise_error
        expect(notifier).to be_eql(Rollbar.notifier)
      end
    end

    context 'if the block creates a new thread' do
      let(:block) do
        proc do
          Thread.new do
            scope = Rollbar.notifier.configuration.payload_options
            Thread.main[:inner_scope] = scope
          end.join
        end
      end

      let(:scope) do
        { :foo => 'bar' }
      end

      it 'maintains the parent thread notifier scope' do
        Rollbar.scoped(scope, &block)

        expect(Thread.main[:inner_scope]).to be_eql(scope)
      end
    end
  end

  describe '.scope!' do
    let(:new_scope) do
      { :person => { :id => 1 } }
    end

    before { reconfigure_notifier }

    it 'adds the new scope to the payload options' do
      configuration = Rollbar.notifier.configuration
      Rollbar.scope!(new_scope)

      expect(configuration.payload_options).to be_eql(new_scope)
    end
  end

  describe '.reset_notifier' do
    it 'resets the notifier' do
      notifier1_id = Rollbar.notifier.object_id

      Rollbar.reset_notifier!
      expect(Rollbar.notifier.object_id).not_to be_eql(notifier1_id)
    end
  end

  describe '.process_payload' do
    context 'if there is an exception sending the payload' do
      let(:exception) { StandardError.new('error message') }
      let(:payload) { { :foo => :bar } }

      it 'logs the error and the payload' do
        allow(Rollbar.notifier).to receive(:send_payload).and_raise(exception)
        expect(Rollbar.notifier).to receive(:log_error)

        expect { Rollbar.notifier.process_payload(payload) }.to raise_error(exception)
      end
    end
  end

  describe '.process_from_async_handler' do
    context 'with errors' do
      let(:exception) { StandardError.new('the error') }

      it 'raises anything and sends internal error' do
        allow(Rollbar.notifier).to receive(:process_payload).and_raise(exception)
        expect(Rollbar.notifier).to receive(:report_internal_error).with(exception)

        expect do
          Rollbar.notifier.process_from_async_handler({})
        end.to raise_error(exception)

        rollbar_do_not_report = exception.instance_variable_get(:@_rollbar_do_not_report)
        expect(rollbar_do_not_report).to be_eql(true)
      end
    end
  end

  describe '#custom_data' do
    before do
      Rollbar.configure do |config|
        config.custom_data_method = proc { raise 'this-will-raise' }
      end

      expect_any_instance_of(Rollbar::Notifier).to receive(:error).and_return(report_data)
    end

    context 'with uuid in reported data' do
      next unless defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)

      let(:report_data) { { :uuid => SecureRandom.uuid } }
      let(:expected_url) { "https://rollbar.com/instance/uuid?uuid=#{report_data[:uuid]}" }

      it 'returns the uuid in :_error_in_custom_data_method' do
        expect(notifier.custom_data).to be_eql(:_error_in_custom_data_method => expected_url)
      end
    end

    context 'without uuid in reported data' do
      let(:report_data) { { :some => 'other-data' } }

      it 'returns the uuid in :_error_in_custom_data_method' do
        expect(notifier.custom_data).to be_eql({})
      end
    end
  end

  describe '.preconfigure'do
    before do
      Rollbar.unconfigure
      Rollbar.reset_notifier!
    end

    it 'resets the notifier' do
      Rollbar.configure do |config|
        config.access_token = 'foo'
      end

      Thread.new {}

      Rollbar.preconfigure do |config|
        config.root = 'bar'
      end

      notifier_config = Rollbar.notifier.configuration
      expect(notifier_config.root).to be_eql('bar')
    end
  end

  # configure with some basic params
  def configure
    reconfigure_notifier
  end
end
