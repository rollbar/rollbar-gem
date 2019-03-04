require 'spec_helper'
require 'rollbar/configuration'
require 'rollbar/item'
require 'rollbar/lazy_store'

describe Rollbar::Item do
  let(:notifier) { double('notifier', :safely => safely_notifier) }
  let(:safely_notifier) { double('safely_notifier') }
  let(:logger) { double }
  let(:configuration) do
    c = Rollbar::Configuration.new
    c.enabled = true
    c.access_token = 'footoken'
    c.root = '/foo/'
    c.framework = 'Rails'
    c
  end
  let(:level) { 'info' }
  let(:message) { 'message' }
  let(:exception) {}
  let(:extra) {}
  let(:scope) {}
  let(:context) {}

  let(:options) do
    {
      :level => level,
      :message => message,
      :exception => exception,
      :extra => extra,
      :configuration => configuration,
      :logger => logger,
      :scope => scope,
      :notifier => notifier,
      :context => context
    }
  end

  subject { described_class.new(options) }

  describe '#build' do
    let(:payload) { subject.build }

    context 'a basic payload' do
      let(:extra) { {:key => 'value', :hash => {:inner_key => 'inner_value'}} }

      it 'calls Rollbar::Util.enforce_valid_utf8' do
        expect(Rollbar::Util).to receive(:enforce_valid_utf8).with(kind_of(Hash))

        subject.build
      end

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
        payload['data'][:framework].should == configuration.framework
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
      configuration.payload_options = { :some_new_key => 'some new value' }

      payload['data'][:some_new_key].should == 'some new value'
    end

    it 'should overwrite existing keys from payload_options' do
      payload_options = {
        :notifier => 'bad notifier',
        :server => { :host => 'new host', :new_server_key => 'value' }
      }
      configuration.payload_options = payload_options

      payload['data'][:notifier].should == 'bad notifier'
      payload['data'][:server][:host].should == 'new host'
      payload['data'][:server][:root].should_not be_nil
      payload['data'][:server][:new_server_key].should == 'value'
    end

    it 'should have default environment "unspecified"' do
      configuration.environment = nil

      payload['data'][:environment].should == 'unspecified'
    end

    it 'should have an overridden environment' do
      configuration.environment = 'overridden'

      payload['data'][:environment].should == 'overridden'
    end

    it 'should not have custom data under default configuration' do
      payload['data'][:body][:message][:extra].should be_nil
    end

    it 'should have custom message data when custom_data_method is configured' do
      configuration.custom_data_method = lambda { {:a => 1, :b => [2, 3, 4]} }

      payload['data'][:body][:message][:extra].should_not be_nil
      payload['data'][:body][:message][:extra][:a].should == 1
      payload['data'][:body][:message][:extra][:b][2].should == 4
    end

    context do
      let(:context) { { :controller => "ExampleController" } }

      it 'should have access to the context in custom_data_method' do
        configuration.custom_data_method = lambda do |message, exception, context|
          { :result => "MyApp#" + context[:controller] }
        end

        payload['data'][:body][:message][:extra].should_not be_nil
        payload['data'][:body][:message][:extra][:result].should == "MyApp#"+context[:controller]
      end

      it 'should not include data passed in :context if there is no custom_data_method configured' do
        configuration.custom_data_method = nil

        payload['data'][:body][:message][:extra].should be_nil
      end

      it 'should have access to the message in custom_data_method' do
        configuration.custom_data_method = lambda do |message, exception, context|
          { :result => "Transformed in custom_data_method: " + message }
        end

        payload['data'][:body][:message][:extra].should_not be_nil
        payload['data'][:body][:message][:extra][:result].should == "Transformed in custom_data_method: " + message
      end

      context do
        let(:exception) { Exception.new "Exception to test custom_data_method" }

        it 'should have access to the current exception in custom_data_method' do
          configuration.custom_data_method = lambda do |message, exception, context|
            { :result => "Transformed in custom_data_method: " + exception.message }
          end

          payload['data'][:body][:trace][:extra].should_not be_nil
          payload['data'][:body][:trace][:extra][:result].should == "Transformed in custom_data_method: " + exception.message
        end
      end
    end

    context do
      let(:extra) do
        { :c => {:e => 'g' }, :f => 'f' }
      end

      it 'should merge extra data into custom message data' do
        custom_method = lambda do
          { :a => 1,
            :b => [2, 3, 4],
            :c => { :d => 'd', :e => 'e' },
            :f => ['1', '2']
          }
        end
        configuration.custom_data_method = custom_method

        payload['data'][:body][:message][:extra].should_not be_nil
        payload['data'][:body][:message][:extra][:a].should == 1
        payload['data'][:body][:message][:extra][:b][2].should == 4
        payload['data'][:body][:message][:extra][:c][:d].should == 'd'
        payload['data'][:body][:message][:extra][:c][:e].should == 'g'
        payload['data'][:body][:message][:extra][:f].should == 'f'
      end
    end

    context 'with custom_data_method crashing' do
      next unless defined?(SecureRandom) && SecureRandom.respond_to?(:uuid)

      let(:crashing_exception) { StandardError.new }
      let(:custom_method) { proc { raise crashing_exception } }
      let(:extra) { { :foo => :bar } }
      let(:custom_data_report) do
        { :_error_in_custom_data_method => SecureRandom.uuid }
      end
      let(:expected_extra) { extra.merge(custom_data_report) }

      before do
        configuration.custom_data_method = custom_method
      end

      it 'doesnt crash the report' do
        expect(subject).to receive(:report_custom_data_error).once.and_return(custom_data_report)

        expect(payload['data'][:body][:message][:extra]).to be_eql(expected_extra)
      end

      context 'and for some reason the safely.error returns a String' do
        it 'returns an empty Hash' do
          allow(safely_notifier).to receive(:error).and_return('ignored')

          expect(payload['data'][:body][:message][:extra]).to be_eql(extra)
        end
      end
    end

    it 'should include project_gem_paths' do
      gems = Gem::Specification.map(&:name)
      project_gems = ['rails']
      project_gems << 'rspec' if gems.include?('rspec')
      project_gems << 'rspec-core' if gems.include?('rspec-core')

      configuration.project_gems = project_gems

      expect(payload['data'][:project_package_paths].count).to eq(project_gems.size)
    end

    it 'should include a code_version' do
      configuration.code_version = 'abcdef'

      payload['data'][:code_version].should == 'abcdef'
    end

    it 'should have the right hostname' do
      payload['data'][:server][:host].should == Socket.gethostname
    end

    it 'should have root and branch set when configured' do
      configuration.root = '/path/to/root'
      configuration.branch = 'master'

      payload['data'][:server][:root].should == '/path/to/root'
      payload['data'][:server][:branch].should == 'master'
    end

    context 'build_payload_body' do
      let(:exception) do
        begin
          foo = bar
        rescue => e
          e
        end
      end

      context 'with no exception' do
        let(:exception) { nil }

        it 'should build a message body when no exception is passed in' do
          payload['data'][:body][:message][:body].should == 'message'
          payload['data'][:body][:message][:extra].should be_nil
          payload['data'][:body][:trace].should be_nil
        end

        context 'and extra data' do
          let(:extra) do
            {:a => 'b'}
          end

          it 'should build a message body when no exception and extra data is passed in' do
            payload['data'][:body][:message][:body].should == 'message'
            payload['data'][:body][:message][:extra].should == {:a => 'b'}
            payload['data'][:body][:trace].should be_nil
          end
        end
      end

      it 'should build an exception body when one is passed in' do
        body = payload['data'][:body]
        body[:message].should be_nil

        trace = body[:trace]
        trace.should_not be_nil
        trace[:extra].should be_nil

        trace[:exception][:class].should_not be_nil
        trace[:exception][:message].should_not be_nil
      end

      context 'with extra data' do
        let(:extra) do
          {:a => 'b'}
        end

        it 'should build an exception body when one is passed in along with extra data' do
          body = payload['data'][:body]
          body[:message].should be_nil

          trace = body[:trace]
          trace.should_not be_nil

          trace[:exception][:class].should_not be_nil
          trace[:exception][:message].should_not be_nil
          trace[:extra].should == {:a => 'b'}
        end
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

      it 'should build valid exception data' do
        body = payload['data'][:body]
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

      context 'with description message' do
        let(:message) { 'exception description' }

        it 'should build exception data with a description' do
          body = payload['data'][:body]

          trace = body[:trace]

          trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
          trace[:exception][:description].should == 'exception description'
        end

        context 'and extra data' do
          let(:extra) do
            {:key => 'value', :hash => {:inner_key => 'inner_value'}}
          end

          it 'should build exception data with a description and extra data' do
            body = payload['data'][:body]
            trace = body[:trace]

            trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
            trace[:exception][:description].should == 'exception description'
            trace[:extra][:key].should == 'value'
            trace[:extra][:hash].should == {:inner_key => 'inner_value'}
          end
        end
      end

      context 'with extra data' do
        let(:extra) do
          {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        end
        it 'should build exception data with a extra data' do
          body = payload['data'][:body]
          trace = body[:trace]

          trace[:exception][:message].should match(/^(undefined local variable or method `bar'|undefined method `bar' on an instance of)/)
          trace[:extra][:key].should == 'value'
          trace[:extra][:hash].should == {:inner_key => 'inner_value'}
        end
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

        let(:exception) { crashing_code.call }
        let(:message) { 'message' }
        let(:extra) { {} }

        context 'using ruby >= 2.1' do
          next unless Exception.instance_methods.include?(:cause)

          it 'sends the two exceptions in the trace_chain attribute' do
            body = payload['data'][:body]

            body[:trace].should be_nil
            body[:trace_chain].should be_kind_of(Array)

            chain = body[:trace_chain]
            chain[0][:exception][:class].should match(/StandardError/)
            chain[0][:exception][:message].should match(/the error/)

            chain[1][:exception][:class].should match(/CauseException/)
            chain[1][:exception][:message].should match(/the cause/)
          end

          context 'when cause is not an Exception' do
            let(:exception) { Exception.new('custom cause') }

            it 'ignores the cause when it is not an Exception' do
              allow(exception).to receive(:cause) { "Foo" }

              payload['data'][:body][:trace].should_not be_nil
            end
          end

          context 'with cyclic nested exceptions' do
            let(:exception1) { Exception.new('exception1') }
            let(:exception2) { Exception.new('exception2') }
            let(:exception) { exception1 }

            before do
              allow(exception1).to receive(:cause).and_return(exception2)
              allow(exception2).to receive(:cause).and_return(exception1)
            end

            it 'doesnt loop for ever' do
              chain = payload['data'][:body][:trace_chain]

              expect(chain[0][:exception][:message]).to be_eql('exception1')
              expect(chain[1][:exception][:message]).to be_eql('exception2')
            end
          end
        end

        context 'using ruby <= 2.1' do
          next if Exception.instance_methods.include?(:cause)

          it 'sends only the last exception in the trace attribute' do
            body = payload['data'][:body]

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
        payload['data'][:body][:message][:body].should == 'message'
        payload['data'][:body][:trace].should be_nil
      end

      context 'with extra data' do
        let(:extra) do
          {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        end

        it 'should build a message with extra data' do
          payload['data'][:body][:message][:body].should == 'message'
          payload['data'][:body][:message][:extra][:key].should == 'value'
          payload['data'][:body][:message][:extra][:hash].should == {:inner_key => 'inner_value'}
        end
      end

      context 'with empty message and extra data' do
        let(:message) { nil }
        let(:extra) do
          {:key => 'value', :hash => {:inner_key => 'inner_value'}}
        end

        it 'should build an empty message with extra data' do
          payload['data'][:body][:message][:body].should == 'Empty message'
          payload['data'][:body][:message][:extra][:key].should == 'value'
          payload['data'][:body][:message][:extra][:hash].should == {:inner_key => 'inner_value'}
        end
      end
    end

    context 'with transform handlers in configuration' do
      let(:scope) { Rollbar::LazyStore.new({ :bar => :foo }) }
      let(:message) { 'message' }
      let(:exception) { Exception.new }
      let(:extra) { { :foo => :bar } }
      let(:level) { 'error' }

      context 'without mutation in payload' do
        let(:handler) do
          proc do |options|

          end
        end

        before do
          configuration.transform = handler
        end

        it 'calls the handler with the correct options' do
          options = {
            :level => subject.level,
            :scope => subject.scope,
            :exception => subject.exception,
            :message => subject.message,
            :extra => subject.extra,
            :payload => kind_of(Hash)
          }

          expect(handler).to receive(:call).with(options).and_call_original

          subject.build
        end
      end

      context 'with mutation in payload' do
        let(:new_payload) do
          {
            'access_token' => configuration.access_token,
            'data' => {
            }
          }
        end
        let(:handler) do
          proc do |options|
            payload = options[:payload]

            payload.replace(new_payload)
          end
        end

        before do
          configuration.transform = handler
        end

        it 'calls the handler with the correct options' do
          options = {
            :level => level,
            :scope => Rollbar::LazyStore.new(scope),
            :exception => exception,
            :message => message,
            :extra => extra,
            :payload => kind_of(Hash)
          }
          expect(handler).to receive(:call).with(options).and_call_original
          expect(payload).to be_eql(new_payload)
        end
      end

      context 'with two handlers' do
        let(:handler1) { proc { |options|} }
        let(:handler2) { proc { |options|} }

        before do
          configuration.transform << handler1
          configuration.transform << handler2
        end

        context 'and the first one fails' do
          let(:exception) { StandardError.new('foo') }
          let(:handler1) do
            proc { |options|  raise exception }
          end

          it 'doesnt call the second handler and logs the error' do
            expect(handler2).not_to receive(:call)
            expect(logger).to receive(:error).with("[Rollbar] Error calling the `transform` hook: #{exception}")

            subject.build
          end
        end
      end
    end

    describe '#custom_data' do
      before do
        configuration.custom_data_method = proc { raise 'this-will-raise' }

        expect(safely_notifier).to receive(:error).and_return(report_data)
      end

      context 'with uuid in reported data' do
        next unless defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)

        let(:report_data) { { :uuid => SecureRandom.uuid } }
        let(:expected_url) { "https://rollbar.com/instance/uuid?uuid=#{report_data[:uuid]}" }

        it 'returns the uuid in :_error_in_custom_data_method' do
          expect(payload['data'][:body][:message][:extra]).to be_eql(:_error_in_custom_data_method => expected_url)
        end
      end

      context 'without uuid in reported data' do
        let(:report_data) { { :some => 'other-data' } }

        it 'returns empty data' do
          expect(payload['data'][:body][:message][:extra]).to be_eql({})
        end
      end
    end

    context 'server_data' do
      it 'should have the right hostname' do
        payload['data'][:server][:host] == Socket.gethostname
      end

      it 'should have root and branch set when configured' do
        configuration.root = '/path/to/root'
        configuration.branch = 'master'

        payload['data'][:server][:root].should == '/path/to/root'
        payload['data'][:server][:branch].should == 'master'
      end

      context 'with custom hostname' do
        before do
          configuration.host = host
        end

        let(:host) { 'my-custom-hostname' }

        it 'sends the custom hostname' do
          expect(payload['data'][:server][:host]).to be_eql(host)
        end
      end
    end

    context 'with ignored person ids' do
      let(:ignored_ids) { [1,2,4] }
      let(:person_data) do
        { :person => {
            :id => 2,
            :username => 'foo'
          }
        }
      end
      let(:scope) { Rollbar::LazyStore.new(person_data) }

      before do
        configuration.person_id_method = :id
        configuration.ignored_person_ids = ignored_ids
      end

      it 'sets ignored property to true' do
        subject.build

        expect(subject).to be_ignored
      end
    end

  end # end #build

  describe '#dump' do
    context 'with recursing instance in payload and ActiveSupport is enabled' do
      class Recurse
        # ActiveSupport also hijacks #to_json, but relies on #as_json to do its real work.
        # The implementation is different earlier vs later than 4.0, but both can
        # be made to fail in the same way with this construct.
        def as_json(*)
          { :self => self }
        end
      end

      let(:payload) do
        {
          :key => {
            :value => Recurse.new
          }
        }
      end
      let(:item) { Rollbar::Item.build_with(payload) }

      it 'fails in ActiveSupport with stack too deep' do
        begin
          _json = item.dump
        rescue NoMemoryError, SystemStackError, Java::JavaLang::StackOverflowError
          # Item#dump fails with SystemStackError (ActiveSupport > 4.0)
          # or NoMemoryError (ActiveSupport <= 4.0) which, as system exceptions
          # not a StandardError, cannot be tested by `expect().to raise_error`
          error = :SystemError
        end

        expect(error).to be_eql(:SystemError)
      end
    end

    context 'with Redis::Connection payload and ActiveSupport is enabled' do
      # This tests an issue in ActiveSupport 4.1.x - 5.1.x, where the JSON serializer
      # calls `to_a` on a TCPSocket object and hangs because of a bug in BasicSocket.
      #
      # See lib/rollbar/plugins/basic_socket.rb for the relevant patch.
      #
      # The test has been refactored here to not require a full redis client and
      # dependency on redis-server. Trying to instantiate just a TCPSocket (or similar)
      # didn't exercise the failure condition.
      #
      let(:redis_connection) do
        ::Redis::Connection::Ruby.connect(:host => '127.0.0.1', :port => 6370) # try to pick a polite port
      end

      let(:payload) do
        {
          :key => {
            :value => redis_connection
          }
        }
      end
      let(:item) { Rollbar::Item.build_with(payload) }

      it 'serializes Redis::Connection without crash or hang' do
        json = nil

        ::TCPServer.open('127.0.0.1', 6370) do |_serv|
          json = item.dump
        end

        expect(json).to be_kind_of(String)
      end
    end

    context 'with too large payload', :fixture => :payload do
      let(:payload_fixture) { 'payloads/sample.trace.json' }
      let(:item) do
        Rollbar::Item.build_with(payload,
                                 :notifier => notifier,
                                 :configuration => configuration,
                                 :logger => logger)
      end

      before do
        allow(Rollbar::Truncation).to receive(:truncate?).and_return(true)
      end

      it 'calls Notifier#send_failsafe and logs the error' do
        original_size = Rollbar::JSON.dump(payload).bytesize
        final_size = Rollbar::Truncation.truncate(payload.clone).bytesize
        # final_size = original_size
        rollbar_message = "Could not send payload due to it being too large after truncating attempts. Original size: #{original_size} Final size: #{final_size}"
        uuid = payload['data']['uuid']
        host = payload['data']['server']['host']
        log_message = "[Rollbar] Payload too large to be sent for UUID #{uuid}: #{Rollbar::JSON.dump(payload)}"

        expect(notifier).to receive(:send_failsafe).with(rollbar_message, nil, uuid, host)
        expect(logger).to receive(:error).with(log_message)

        item.dump
      end

      context 'with missing server data' do
        it 'calls Notifier#send_failsafe and logs the error' do
          payload['data'].delete('server')
          original_size = Rollbar::JSON.dump(payload).bytesize
          final_size = Rollbar::Truncation.truncate(payload.clone).bytesize
          # final_size = original_size
          rollbar_message = "Could not send payload due to it being too large after truncating attempts. Original size: #{original_size} Final size: #{final_size}"
          uuid = payload['data']['uuid']
          log_message = "[Rollbar] Payload too large to be sent for UUID #{uuid}: #{Rollbar::JSON.dump(payload)}"

          expect(notifier).to receive(:send_failsafe).with(rollbar_message, nil, uuid, nil)
          expect(logger).to receive(:error).with(log_message)

          item.dump
        end
      end
    end
  end
end
