require 'spec_helper'
require 'rollbar/configuration'
require 'rollbar/item'
require 'rollbar/lazy_store'
require 'rollbar/middleware/js/json_value'

describe Rollbar::Item do
  let(:notifier) { double('notifier', :safely => safely_notifier) }
  let(:safely_notifier) { double('safely_notifier') }
  let(:logger) { double }
  let(:configuration) do
    Rollbar.configure do |c|
      c.enabled = true
      c.access_token = 'footoken'
      c.randomize_scrub_length = false
      c.root = '/foo/'
      c.framework = 'Rails'
    end
    Rollbar.configuration
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

    context 'when use_payload_access_token is set' do
      let(:configuration) do
        Rollbar.configure do |c|
          c.enabled = true
          c.access_token = 'footoken'
          c.use_payload_access_token = true
        end
        Rollbar.configuration
      end

      it 'adds token to payload' do
        payload['access_token'].should == 'footoken'
      end
    end

    context 'a basic payload' do
      let(:extra) { { :key => 'value', :hash => { :inner_key => 'inner_value' } } }

      it 'calls Rollbar::Util.enforce_valid_utf8' do
        expect(Rollbar::Util).to receive(:enforce_valid_utf8).with(kind_of(Hash))

        subject.build
      end

      it 'should have the correct root-level keys' do
        payload.keys.should match_array(['data'])
      end

      it 'should have the correct data keys' do
        payload['data'].keys.should include(:timestamp, :environment, :level,
                                            :language, :framework, :server,
                                            :notifier, :body)
      end

      it 'should have the correct notifier name and version' do
        payload['data'][:notifier][:name].should eq('rollbar-gem')
        payload['data'][:notifier][:version].should eq(Rollbar::VERSION)
      end

      it 'should have the correct language and framework' do
        payload['data'][:language].should eq('ruby')
        payload['data'][:framework].should eq(configuration.framework)
        payload['data'][:framework].should match(/^Rails/)
      end

      it 'should have the correct server keys' do
        payload['data'][:server].keys.should match_array([:host, :root, :pid])
      end

      it 'should have the correct level and message body' do
        payload['data'][:level].should eq('info')
        payload['data'][:body][:message][:body].should eq('message')
      end
    end

    it 'should merge in a new key from payload_options' do
      configuration.payload_options = { :some_new_key => 'some new value' }

      payload['data'][:some_new_key].should eq('some new value')
    end

    it 'should overwrite existing keys from payload_options' do
      payload_options = {
        :notifier => 'bad notifier',
        :server => { :host => 'new host', :new_server_key => 'value' }
      }
      configuration.payload_options = payload_options

      payload['data'][:notifier].should eq('bad notifier')
      payload['data'][:server][:host].should eq('new host')
      payload['data'][:server][:root].should_not be_nil
      payload['data'][:server][:new_server_key].should eq('value')
    end

    it 'should have default environment "unspecified"' do
      configuration.environment = nil

      payload['data'][:environment].should eq('unspecified')
    end

    it 'should have an overridden environment' do
      configuration.environment = 'overridden'

      payload['data'][:environment].should eq('overridden')
    end

    it 'should not have custom data under default configuration' do
      payload['data'][:body][:message][:extra].should be_nil
    end

    it 'should have custom message data when custom_data_method is configured' do
      configuration.custom_data_method = lambda { { :a => 1, :b => [2, 3, 4] } }

      payload['data'][:body][:message][:extra].should_not be_nil
      payload['data'][:body][:message][:extra][:a].should eq(1)
      payload['data'][:body][:message][:extra][:b][2].should eq(4)
    end

    context 'ActiveSupport >= 4.1',
            :if => Gem.loaded_specs['activesupport'].version >= Gem::Version.new('4.1') do
      it 'should have correct configured_options object' do
        payload['data'][:notifier][:configured_options][:access_token].should eq('******')
        payload['data'][:notifier][:configured_options][:root].should eq('/foo/')
        payload['data'][:notifier][:configured_options][:framework].should eq('Rails')
      end
    end

    context 'ActiveSupport < 4.1',
            :if => Gem.loaded_specs['activesupport'].version < Gem::Version.new('4.1') do
      it 'should have configured_options message' do
        payload['data'][:notifier][:configured_options].instance_of?(String)
      end
    end

    context do
      let(:context) { { :controller => 'ExampleController' } }

      it 'should have access to the context in custom_data_method' do
        configuration.custom_data_method = lambda do |_message, _exception, context|
          { :result => "MyApp##{context[:controller]}" }
        end

        payload['data'][:body][:message][:extra].should_not be_nil
        payload['data'][:body][:message][:extra][:result]
          .should == "MyApp##{context[:controller]}"
      end

      it 'should not include data passed in :context if there is no custom_data_method' do
        configuration.custom_data_method = nil

        payload['data'][:body][:message][:extra].should be_nil
      end

      it 'should have access to the message in custom_data_method' do
        configuration.custom_data_method = lambda do |message, _exception, _context|
          { :result => "Transformed in custom_data_method: #{message}" }
        end

        extra = payload['data'][:body][:message][:extra]
        extra.should_not be_nil
        extra[:result].should == "Transformed in custom_data_method: #{message}"
      end

      context do
        let(:exception) { Exception.new 'Exception to test custom_data_method' }

        it 'should have access to the current exception in custom_data_method' do
          configuration.custom_data_method = lambda do |_message, exception, _context|
            { :result => "Transformed in custom_data_method: #{exception.message}" }
          end

          extra = payload['data'][:body][:trace][:extra]
          extra.should_not be_nil
          expect(extra[:result])
            .to eq("Transformed in custom_data_method: #{exception.message}")
        end
      end
    end

    context do
      let(:extra) do
        { :c => { :e => 'g' }, :f => 'f' }
      end

      it 'should merge extra data into custom message data' do
        custom_method = lambda do
          { :a => 1,
            :b => [2, 3, 4],
            :c => { :d => 'd', :e => 'e' },
            :f => %w[1 2] }
        end
        configuration.custom_data_method = custom_method

        payload['data'][:body][:message][:extra].should_not be_nil
        payload['data'][:body][:message][:extra][:a].should eq(1)
        payload['data'][:body][:message][:extra][:b][2].should eq(4)
        payload['data'][:body][:message][:extra][:c][:d].should eq('d')
        payload['data'][:body][:message][:extra][:c][:e].should eq('g')
        payload['data'][:body][:message][:extra][:f].should eq('f')
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
        expect(subject).to receive(:report_custom_data_error)
          .once.and_return(custom_data_report)

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

      payload['data'][:code_version].should eq('abcdef')
    end

    it 'should have the right hostname' do
      payload['data'][:server][:host].should eq(Socket.gethostname)
    end

    it 'should have root and branch set when configured' do
      configuration.root = '/path/to/root'
      configuration.branch = 'master'

      payload['data'][:server][:root].should eq('/path/to/root')
      payload['data'][:server][:branch].should eq('master')
    end

    context 'build_payload_body' do
      let(:exception) do
        begin
          foo = bar # rubocop:disable Lint/UselessAssignment
        rescue StandardError => e
          e
        end
      end

      context 'with no exception' do
        let(:exception) { nil }

        it 'should build a message body' do
          payload['data'][:body][:message][:body].should eq('message')
          payload['data'][:body][:message][:extra].should be_nil
          payload['data'][:body][:trace].should be_nil
        end

        context 'and extra data' do
          let(:extra) do
            { :a => 'b' }
          end

          it 'should build a message body' do
            payload['data'][:body][:message][:body].should eq('message')
            payload['data'][:body][:message][:extra].should eq({ :a => 'b' })
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
          { :a => 'b' }
        end

        it 'should build an exception body' do
          body = payload['data'][:body]
          body[:message].should be_nil

          trace = body[:trace]
          trace.should_not be_nil

          trace[:exception][:class].should_not be_nil
          trace[:exception][:message].should_not be_nil
          trace[:extra].should == { :a => 'b' }
        end
      end
    end

    context 'build_payload_body_exception' do
      let(:exception) do
        begin
          foo = bar # rubocop:disable Lint/UselessAssignment
        rescue StandardError => e
          e
        end
      end

      let(:pattern) do
        /^(undefined\ local\ variable\ or\ method\ `bar'|
          undefined\ method\ `bar'\ on\ an\ instance\ of)/x
      end

      it 'should build valid exception data' do
        body = payload['data'][:body]
        body[:message].should be_nil

        trace = body[:trace]

        frames = trace[:frames]
        frames.should be_a_kind_of(Array)
        frames.each do |frame|
          frame[:filename].should be_a_kind_of(String)
          frame[:lineno].should be_a_kind_of(Integer)
          frame[:method].should be_a_kind_of(String) if frame[:method]
        end

        # should be NameError, but can be NoMethodError sometimes on rubinius 1.8
        # http://yehudakatz.com/2010/01/02/the-craziest-fing-bug-ive-ever-seen/
        trace[:exception][:class].should match(/^(NameError|NoMethodError)$/)
        trace[:exception][:message].should match(pattern)
      end

      context 'with description message' do
        let(:message) { 'exception description' }

        it 'should build exception data with a description' do
          body = payload['data'][:body]

          trace = body[:trace]

          trace[:exception][:message].should match(pattern)
          trace[:exception][:description].should eq('exception description')
        end

        context 'and extra data' do
          let(:extra) do
            { :key => 'value', :hash => { :inner_key => 'inner_value' } }
          end

          it 'should build exception data with a description and extra data' do
            body = payload['data'][:body]
            trace = body[:trace]

            trace[:exception][:message].should match(pattern)
            trace[:exception][:description].should eq('exception description')
            trace[:extra][:key].should eq('value')
            trace[:extra][:hash].should eq({ :inner_key => 'inner_value' })
          end
        end
      end

      context 'with extra data' do
        let(:extra) do
          { :key => 'value', :hash => { :inner_key => 'inner_value' } }
        end
        it 'should build exception data with a extra data' do
          body = payload['data'][:body]
          trace = body[:trace]

          trace[:exception][:message].should match(pattern)
          trace[:extra][:key].should eq('value')
          trace[:extra][:hash].should eq({ :inner_key => 'inner_value' })
        end
      end

      context 'with error context' do
        let(:context) do
          { :key => 'value', :hash => { :inner_key => 'inner_value' } }
        end
        it 'should build exception data with a extra data' do
          exception.rollbar_context = context

          body = payload['data'][:body]
          trace = body[:trace]

          trace[:exception][:message].should match(pattern)
          trace[:extra][:key].should eq('value')
          trace[:extra][:hash].should eq({ :inner_key => 'inner_value' })
        end
      end

      context 'with nested exceptions' do
        let(:crashing_code) do
          proc do
            begin
              begin
                raise CauseException, 'the cause'
              rescue StandardError
                raise StandardError, 'the error'
              end
            rescue StandardError => e
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
              allow(exception).to receive(:cause) { 'Foo' }

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
        payload['data'][:body][:message][:body].should eq('message')
        payload['data'][:body][:trace].should be_nil
      end

      context 'with extra data' do
        let(:extra) do
          { :key => 'value', :hash => { :inner_key => 'inner_value' } }
        end

        it 'should build a message with extra data' do
          payload['data'][:body][:message][:body].should eq('message')
          payload['data'][:body][:message][:extra][:key].should eq('value')
          payload['data'][:body][:message][:extra][:hash]
            .should eq({ :inner_key => 'inner_value' })
        end
      end

      context 'with empty message and extra data' do
        let(:message) { nil }
        let(:extra) do
          { :key => 'value', :hash => { :inner_key => 'inner_value' } }
        end

        it 'should build an empty message with extra data' do
          payload['data'][:body][:message][:body].should eq('Empty message')
          payload['data'][:body][:message][:extra][:key].should eq('value')
          payload['data'][:body][:message][:extra][:hash]
            .should eq({ :inner_key => 'inner_value' })
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
        let(:handler1) { proc { |options| } }
        let(:handler2) { proc { |options| } }

        before do
          configuration.transform << handler1
          configuration.transform << handler2
        end

        context 'and the first one fails' do
          let(:exception) { StandardError.new('foo') }
          let(:handler1) do
            proc { |_options| raise exception }
          end

          it 'doesnt call the second handler and logs the error' do
            message = "[Rollbar] Error calling the `transform` hook: #{exception}"
            expect(handler2).not_to receive(:call)
            expect(logger).to receive(:error).with(message)

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
        next unless defined?(SecureRandom) && SecureRandom.respond_to?(:uuid)

        let(:report_data) { { :uuid => SecureRandom.uuid } }
        let(:expected_url) do
          "https://rollbar.com/instance/uuid?uuid=#{report_data[:uuid]}"
        end

        it 'returns the uuid in :_error_in_custom_data_method' do
          expect(payload['data'][:body][:message][:extra])
            .to be_eql(:_error_in_custom_data_method => expected_url)
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

        payload['data'][:server][:root].should eq('/path/to/root')
        payload['data'][:server][:branch].should eq('master')
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
      let(:ignored_ids) { [1, 2, 4] }
      let(:person_data) do
        { :person => {
          :id => 2,
          :username => 'foo'
        } }
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
  end

  describe '#build_with' do
    context 'when use_payload_access_token is set' do
      let(:configuration) do
        Rollbar.configure do |c|
          c.enabled = true
          c.access_token = 'new-token'
          c.use_payload_access_token = true
        end
        Rollbar.configuration
      end

      context 'when no token is in payload' do
        it 'adds token to payload' do
          item = described_class.build_with(
            { 'foo' => 'bar' },
            { :configuration => configuration }
          )
          payload = item.payload

          expect(payload['access_token']).to be_eql('new-token')
        end
      end

      context 'when token is in payload' do
        it 'preserves original token' do
          item = described_class.build_with(
            { 'foo' => 'bar', 'access_token' => 'original-token' },
            { :configuration => configuration }
          )
          payload = item.payload

          expect(payload['access_token']).to be_eql('original-token')
        end
      end
    end
  end

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

      it "doesn't fail in ActiveSupport >= 4.1" do
        begin
          _json = item.dump

        # If you get an uninitialized constant "Java" error, it just means an
        # unexpected exception occurred (i.e. one not in the below list) and
        # caused Java::JavaLang::StackOverflowError.
        # If the test case is working correctly, this shouldn't happen and the
        # Java error type will only be evaluated on JRuby builds.
        rescue NoMemoryError,
               SystemStackError,
               ActiveSupport::JSON::Encoding::CircularReferenceError,
               Java::JavaLang::StackOverflowError

          # If ActiveSupport is invoked, we'll end up here.
          # Item#dump fails with SystemStackError (ActiveSupport > 4.0)
          # or NoMemoryError (ActiveSupport <= 4.0) which, as system exceptions
          # not a StandardError, cannot be tested by `expect().to raise_error`
          error = :SystemError
        end

        if Gem::Version.new(ActiveSupport::VERSION::STRING) >= Gem::Version.new('4.1.0')
          expect(error).not_to be_eql(:SystemError)
        else
          # This ActiveSupport is vulnerable to circular reference errors, and is
          # virtually impossible to correct, because these versions of AS even
          # hook into core Ruby JSON.
          expect(error).to be_eql(:SystemError)
        end
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
        ::Redis::Connection::Ruby.connect(
          :host => '127.0.0.1',
          :port => 6370 # try to pick a polite port
        )
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
        attempts = []
        final_size = Rollbar::Truncation.truncate(Rollbar::Util.deep_copy(payload),
                                                  attempts).bytesize
        # final_size = original_size
        rollbar_message = 'Could not send payload due to it being too large ' \
          'after truncating attempts. Original size: ' \
          "#{original_size} Attempts: #{attempts.join(', ')} Final size: #{final_size}"
        uuid = payload['data']['uuid']
        host = payload['data']['server']['host']
        log_message = '[Rollbar] Payload too large to be sent for UUID ' \
          "#{uuid}: #{Rollbar::JSON.dump(payload)}"

        expect(notifier)
          .to receive(:send_failsafe)
          .with(rollbar_message, nil, hash_including(:uuid => uuid, :host => host))
        expect(logger).to receive(:error).with(log_message)

        item.dump
      end

      context 'with missing server data' do
        it 'calls Notifier#send_failsafe and logs the error' do
          payload['data'].delete('server')
          original_size = Rollbar::JSON.dump(payload).bytesize
          attempts = []
          final_size = Rollbar::Truncation.truncate(Rollbar::Util.deep_copy(payload),
                                                    attempts).bytesize
          # final_size = original_size
          rollbar_message = 'Could not send payload due to it being too large ' \
            'after truncating attempts. Original size: ' \
            "#{original_size} Attempts: #{attempts.join(', ')} Final size: #{final_size}"
          uuid = payload['data']['uuid']
          log_message = '[Rollbar] Payload too large to be sent for UUID ' \
            "#{uuid}: #{Rollbar::JSON.dump(payload)}"

          expect(notifier).to receive(:send_failsafe).with(rollbar_message, nil,
                                                           hash_including(:uuid => uuid))
          expect(logger).to receive(:error).with(log_message)

          item.dump
        end
      end
    end

    context 'with js function options' do
      let(:payload) do
        {
          :js_options => {
            :checkIgnore => Rollbar::JSON::Value.new('function(){ alert("bar") }')
          }
        }
      end
      let(:item) { Rollbar::Item.build_with(payload) }

      it 'stringifies the js function' do
        json = item.dump

        expect(json).to include(%q["function(){ alert("bar") }"])
      end
    end
  end
end
