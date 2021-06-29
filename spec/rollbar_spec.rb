# encoding: UTF-8

require 'logger'
require 'socket'
require 'girl_friday'
require 'redis'
require 'active_support/core_ext/object'
require 'active_support/json/encoding'

require 'rollbar/item'
require 'ostruct'

require 'spec_helper'

begin
  require 'rollbar/delay/sidekiq'
  require 'rollbar/delay/sucker_punch'
rescue LoadError
  # Skip loading
end

begin
  require 'sucker_punch'
  require 'sucker_punch/testing/inline'
rescue LoadError
  # Skip loading
end

begin
  require 'rollbar/delay/shoryuken'
rescue LoadError
  # Skip loading
end

describe Rollbar do
  let(:notifier) { Rollbar.notifier }

  before do
    Rollbar.clear_notifier!
    configure
  end

  context 'when notifier has been used before configure it' do
    before do
      Rollbar.clear_notifier!
    end

    it 'is finally reset' do
      Rollbar.log_debug('Testing notifier')
      expect(Rollbar.error('error message')).to be_eql('disabled')

      reconfigure_notifier

      expect(Rollbar.error('error message')).not_to be_eql('disabled')
    end
  end

  context 'when rollbar is unconfigured' do
    before do
      reset_configuration
    end

    it 'should not send events, and should be disabled' do
      expect(Rollbar.configuration.access_token).to be_eql(nil)
      expect(Rollbar.notifier).to receive(:log).and_call_original
      expect(Rollbar.notifier).to_not receive(:report)
      expect(Rollbar.error('error message')).to be_eql('disabled')
    end

    it 'should have empty configured options' do
      expect(Rollbar.configuration.configured_options.configured).to be_eql({})
    end
  end

  shared_examples 'stores the root notifier' do
  end

  shared_examples 'configured options' do
    it 'tracks the configured options' do
      Rollbar.reconfigure do |c|
        c.environment = 'staging'
      end
      environment = Rollbar.configuration.configured_options.configured[:environment]
      expect(environment).to be_eql('staging')
    end
  end

  describe '.configure' do
    before { Rollbar.clear_notifier! }

    it 'stores the root notifier' do
      Rollbar.configure { |c| }
      expect(Rollbar.root_notifier).to be(Rollbar.notifier)
    end

    it_behaves_like 'configured options'
  end

  describe '.preconfigure' do
    before { Rollbar.clear_notifier! }

    it 'stores the root notifier' do
      Rollbar.preconfigure { |c| }
      expect(Rollbar.root_notifier).to be(Rollbar.notifier)
    end

    it_behaves_like 'configured options'
  end

  describe '.reconfigure' do
    before { Rollbar.clear_notifier! }

    it 'stores the root notifier' do
      Rollbar.reconfigure { |c| }
      expect(Rollbar.root_notifier).to be(Rollbar.notifier)
    end

    it_behaves_like 'configured options'
  end

  describe '.unconfigure' do
    before { Rollbar.clear_notifier! }

    it 'stores the root notifier' do
      expect(Rollbar.root_notifier).to receive(:unconfigure)

      Rollbar.unconfigure

      expect(Rollbar.root_notifier).to be(Rollbar.notifier)
    end
  end

  context 'Notifier' do
    describe '#log' do
      let(:exception) do
        begin
          _foo = bar
        rescue StandardError => e
          e
        end
      end

      let(:configuration) { Rollbar.configuration }

      context 'executing a Thread before Rollbar is configured' do
        before do
          Rollbar.clear_notifier!

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
        expect(notifier).to receive(:report).with('error', 'test message', nil, nil, nil)
        notifier.log('error', 'test message')
      end

      it 'should report a simple message with extra data' do
        extra_data = { :key => 'value', :hash => { :inner_key => 'inner_value' } }

        expect(notifier).to receive(:report).with('error', 'test message', nil,
                                                  extra_data, nil)
        notifier.log('error', 'test message', extra_data)
      end

      it 'should report an exception' do
        expect(notifier).to receive(:report).with('error', nil, exception, nil, nil)
        notifier.log('error', exception)
      end

      it 'should report an exception with extra data' do
        extra_data = { :key => 'value', :hash => { :inner_key => 'inner_value' } }

        expect(notifier).to receive(:report).with('error', nil, exception, extra_data,
                                                  nil)
        notifier.log('error', exception, extra_data)
      end

      it 'should report an exception with a description' do
        expect(notifier).to receive(:report).with('error', 'exception description',
                                                  exception, nil, nil)
        notifier.log('error', exception, 'exception description')
      end

      it 'should report an exception with a description and extra data' do
        extra_data = { :key => 'value', :hash => { :inner_key => 'inner_value' } }

        expect(notifier).to receive(:report).with('error', 'exception description',
                                                  exception, extra_data, nil)
        notifier.log('error', exception, extra_data, 'exception description')
      end

      # See Notifier#pack_ruby260_bytes for more information.
      context 'with multi-byte characters in the report' do
        extra_data = { :key => "\u3042", :hash => { :inner_key => 'あああ' } }

        it 'should send as multi-byte on ruby != 2.6.0', :if => RUBY_VERSION != '2.6.0' do
          expect_any_instance_of(Net::HTTP::Post).to receive(:body=).with(
            satisfy do |body|
              body.chars.length < body.bytes.length && body.include?('あああ')
            end
          ).and_call_original
          notifier.log('error', 'test message', extra_data)
        end

        it 'should unpack multi-byte and send as single byte on ruby == 2.6.0',
           :if => RUBY_VERSION == '2.6.0' do
          expect_any_instance_of(Net::HTTP::Post).to receive(:body=).with(
            satisfy do |body|
              body.chars.length == body.bytes.length &&
              body.force_encoding('utf-8').include?('あああ')
            end
          ).and_call_original
          notifier.log('error', 'test message', extra_data)
        end
      end

      context 'with :on_error_response hook configured' do
        let!(:notifier) { Rollbar::Notifier.new }
        let(:configuration) do
          config = Rollbar::Configuration.new
          config.access_token = test_access_token
          config.enabled = true

          config.hook :on_error_response do |_response|
            return ':on_error_response executed'
          end

          config
        end
        let(:message) { 'foo' }
        let(:level) { 'foo' }

        before do
          notifier.configuration = configuration
          allow_any_instance_of(Net::HTTP)
            .to receive(:request)
            .and_return(OpenStruct.new(:code => 500, :body => 'Error'))
          @uri = URI.parse(Rollbar::Configuration::DEFAULT_ENDPOINT)
        end

        it 'calls the :on_error_response hook if response status is not 200' do
          expect(Net::HTTP).to receive(:new).with(@uri.host, @uri.port, nil, nil, nil,
                                                  nil).and_call_original
          expect(notifier.configuration.hook(:on_error_response)).to receive(:call)

          notifier.log(level, message)
        end
      end

      context 'with :on_report_internal_error hook configured' do
        let!(:notifier) { Rollbar::Notifier.new }
        let(:configuration) do
          config = Rollbar::Configuration.new
          config.access_token = test_access_token
          config.enabled = true

          config.hook :on_report_internal_error do |_response|
            return ':on_report_internal_error executed'
          end

          config
        end
        let(:message) { 'foo' }
        let(:level) { 'foo' }

        before do
          notifier.configuration = configuration
        end

        it 'calls the :on_report_internal_error hook if' do
          expect(notifier.configuration.hook(:on_report_internal_error)).to receive(:call)
          expect(notifier).to receive(:report) do
            raise StandardError
          end
          notifier.log(level, message)
        end
      end

      context 'an item with a context' do
        let(:context) { { :controller => 'ExampleController' } }

        context 'with a custom_data_method configured' do
          before do
            Rollbar.configure do |config|
              config.custom_data_method = lambda do |_message, _exception, context|
                { :result => "MyApp##{context[:controller]}" }
              end
            end
          end

          it 'should have access to the context data through custom_data_method' do
            result = notifier.log('error', 'Custom message',
                                  :custom_data_method_context => context)

            result[:body][:message][:extra].should_not be_nil
            result[:body][:message][:extra][:result]
              .should eq("MyApp##{context[:controller]}")
            result[:body][:message][:extra][:custom_data_method_context].should be_nil
          end
        end
      end

      context 'with a recurisve custom_data_method call' do
        before do
          Rollbar.configure do |config|
            config.custom_data_method = lambda do
              notifier.error('Recurisve call to rollbar')
            end
          end
        end

        it 'should detect recursion and stop the infinite loop' do
          expect(notifier).to receive(:report).twice.and_call_original
          notifier.log('error', 'Call to Rollbar with custom_data_method')
        end
      end

      context 'when raise_on_error is set' do
        before do
          Rollbar.configure do |config|
            config.raise_on_error = true
          end
        end

        let(:exception) { StandardError.new('error') }

        it 'should raise on an exception event' do
          expect(Rollbar.notifier).to receive(:report).and_return(nil)

          expect do
            Rollbar.notifier.log('error', exception)
          end.to raise_error(exception)
        end

        it 'should not raise on a non-exception event' do
          expect(Rollbar.notifier).to receive(:report).and_return(nil)

          expect do
            Rollbar.notifier.log('error', 'message')
          end.not_to raise_error
        end
      end

      context 'when transmit is not set' do
        before do
          Rollbar.configure do |config|
            config.transmit = false
          end
        end

        it 'should not transmit the payload' do
          expect(Rollbar.notifier).to_not receive(:do_post)

          Rollbar.notifier.log('error', exception)
        end
      end

      context 'when log_payload is set' do
        before do
          Rollbar.configure do |config|
            config.log_payload = true
          end
        end

        it 'should log the payload' do
          data = nil
          allow(Rollbar.notifier).to receive(:log_info) { |arg| data = arg }

          Rollbar.notifier.log('info', 'message')

          expect(data).to eql("[Rollbar] Data: #{Rollbar.last_report}")
        end
      end

      context 'when log_payload is not set' do
        before do
          Rollbar.configure do |config|
            config.log_payload = false
          end
        end

        it 'should log the payload' do
          expect(Rollbar.notifier).to_not receive(:log_data)

          Rollbar.notifier.log('info', 'message')
        end
      end
    end

    context 'with before_process handlers in configuration' do
      let!(:notifier) { Rollbar::Notifier.new }
      let(:scope) { { :bar => :foo } }
      let(:configuration) do
        config = Rollbar::Configuration.new
        config.access_token = test_access_token
        config.enabled = true
        config
      end
      let(:message) { 'message' }
      let(:exception) { Exception.new }
      let(:extra) { { :foo => :bar } }
      let(:level) { 'error' }

      before do
        notifier.configuration = configuration
        notifier.scope!(scope)
      end

      context 'without raise Rollbar::Ignore' do
        let(:handler) do
          proc do |options|
          end
        end

        before do
          configuration.before_process = handler
        end

        it 'calls the handler with the correct options' do
          options = {
            :level => level,
            :scope => Rollbar::LazyStore.new(scope),
            :exception => exception,
            :message => message,
            :extra => extra
          }

          expect(handler).to receive(:call).with(options)
          expect(notifier).to receive(:report).with(level, message, exception, extra, nil)

          notifier.log(level, message, exception, extra)
        end
      end

      context 'setting ignore in the handler' do
        before do
          configuration.before_process = handler
        end

        shared_examples 'call the handler' do
          it "calls with correct options and doesn't call #report" do
            options = {
              :level => level,
              :scope => Rollbar::LazyStore.new(scope),
              :exception => exception,
              :message => message,
              :extra => extra
            }
            expect(handler).to receive(:call).with(options).and_call_original
            expect(notifier).not_to receive(:report)

            result = notifier.log(level, message, exception, extra)

            expect(result).to be_eql('ignored')
          end
        end

        context "returning 'ignored'" do
          let(:handler) do
            proc do |_options|
              'ignored'
            end
          end

          include_examples 'call the handler'
        end

        context 'raising Rollbar::Ignore' do
          let(:handler) do
            proc do |_options|
              raise Rollbar::Ignore
            end
          end

          include_examples 'call the handler'
        end
      end

      context 'with 2 handlers, setting ignore in the first one' do
        before do
          configuration.before_process << handler1
          configuration.before_process << handler2
        end

        shared_examples 'call two handlers' do
          it "calls only the first handler and doesn't calls #report" do
            options = {
              :level => level,
              :scope => Rollbar::LazyStore.new(scope),
              :exception => exception,
              :message => message,
              :extra => extra
            }

            expect(handler1).to receive(:call).with(options).and_call_original
            expect(handler2).not_to receive(:call)
            expect(notifier).not_to receive(:report)

            result = notifier.log(level, message, exception, extra)

            expect(result).to be_eql('ignored')
          end

          context 'if the first handler fails' do
            let(:exception) { StandardError.new('foo') }
            let(:handler1) do
              proc { |_options| raise exception }
            end

            it 'doesnt call the second handler and logs the error' do
              expect(handler2).not_to receive(:call)
              expect(notifier)
                .to receive(:log_error)
                .with("[Rollbar] Error calling the `before_process` hook: #{exception}")

              notifier.log(level, message, exception, extra)
            end
          end
        end

        context "returning 'ignored'" do
          let(:handler1) do
            proc do |_options|
              'ignored'
            end
          end

          let(:handler2) do
            proc do |options|
            end
          end

          include_examples 'call two handlers'
        end
        context 'raising Rollbar::Ignore' do
          let(:handler1) do
            proc do |_options|
              raise Rollbar::Ignore
            end
          end

          let(:handler2) do
            proc do |options|
            end
          end

          include_examples 'call two handlers'
        end
      end
    end

    context 'debug/info/warning/error/critical' do
      let(:exception) do
        begin
          _foo = bar
        rescue StandardError => e
          e
        end
      end

      let(:extra_data) { { :key => 'value', :hash => { :inner_key => 'inner_value' } } }

      it 'should report with a debug level' do
        expect(notifier).to receive(:report).with('debug', nil, exception, nil, nil)
        notifier.debug(exception)

        expect(notifier).to receive(:report).with('debug', 'description', exception, nil,
                                                  nil)
        notifier.debug(exception, 'description')

        expect(notifier).to receive(:report).with('debug', 'description', exception,
                                                  extra_data, nil)
        notifier.debug(exception, 'description', extra_data)
      end

      it 'should report with an info level' do
        expect(notifier).to receive(:report).with('info', nil, exception, nil, nil)
        notifier.info(exception)

        expect(notifier).to receive(:report).with('info', 'description', exception, nil,
                                                  nil)
        notifier.info(exception, 'description')

        expect(notifier).to receive(:report).with('info', 'description', exception,
                                                  extra_data, nil)
        notifier.info(exception, 'description', extra_data)
      end

      it 'should report with a warning level' do
        expect(notifier).to receive(:report).with('warning', nil, exception, nil, nil)
        notifier.warning(exception)

        expect(notifier).to receive(:report).with('warning', 'description', exception,
                                                  nil, nil)
        notifier.warning(exception, 'description')

        expect(notifier).to receive(:report).with('warning', 'description', exception,
                                                  extra_data, nil)
        notifier.warning(exception, 'description', extra_data)
      end

      it 'should report with an error level' do
        expect(notifier).to receive(:report).with('error', nil, exception, nil, nil)
        notifier.error(exception)

        expect(notifier).to receive(:report).with('error', 'description', exception, nil,
                                                  nil)
        notifier.error(exception, 'description')

        expect(notifier).to receive(:report).with('error', 'description', exception,
                                                  extra_data, nil)
        notifier.error(exception, 'description', extra_data)
      end

      it 'should report with a critical level' do
        expect(notifier).to receive(:report).with('critical', nil, exception, nil, nil)
        notifier.critical(exception)

        expect(notifier).to receive(:report).with('critical', 'description', exception,
                                                  nil, nil)
        notifier.critical(exception, 'description')

        expect(notifier).to receive(:report).with('critical', 'description', exception,
                                                  extra_data, nil)
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
            :b => { :c => 'c' }
          }
        end

        notifier_config = notifier.configuration
        notifier2_config = notifier.scope.configuration

        notifier2_config.code_version.should eq('123')
        notifier2_config.should_not equal(notifier_config)
        notifier2_config.payload_options.should_not equal(notifier_config.payload_options)
        notifier2_config.payload_options.should eq(notifier_config.payload_options)
        notifier2_config.payload_options.should eq(:a => 'a',
                                                   :b => { :c => 'c' })
      end

      it 'should not modify any parent notifier configuration' do
        Rollbar.clear_notifier!
        configure
        Rollbar.configuration.code_version.should be_nil
        Rollbar.configuration.payload_options.should be_empty

        notifier = Rollbar.notifier.scope
        notifier.configure do |config|
          config.code_version = '123'
          config.payload_options = {
            :a => 'a',
            :b => { :c => 'c' }
          }
        end

        notifier2 = notifier.scope

        notifier2.configure do |config|
          config.payload_options[:c] = 'c'
        end

        notifier.configuration.payload_options[:c].should be_nil

        notifier3 = notifier2.scope(
          :b => { :c => 3, :d => 'd' }
        )

        notifier3.configure do |config|
          config.code_version = '456'
        end

        notifier.configuration.code_version.should eq('123')
        notifier.configuration.payload_options.should eq(:a => 'a',
                                                         :b => { :c => 'c' })
        notifier2.configuration.code_version.should eq('123')
        notifier2.configuration.payload_options.should eq(:a => 'a',
                                                          :b => { :c => 'c' },
                                                          :c => 'c')
        notifier3.configuration.code_version.should eq('456')
        notifier3.configuration.payload_options.should eq(:a => 'a',
                                                          :b => { :c => 'c' },
                                                          :c => 'c')

        Rollbar.configuration.code_version.should be_nil
        Rollbar.configuration.payload_options.should be_empty
      end
    end

    context 'report' do
      let(:logger_mock) { double('Rails.logger').as_null_object }

      before(:each) do
        configure
        Rollbar.configure do |config|
          config.logger = logger_mock
        end
      end

      after do
        configure
      end

      it "should reject input that doesn't contain an exception, message or extra data" do
        message = '[Rollbar] ' \
          'Tried to send a report with no message, exception or extra data.'
        expect(logger_mock).to receive(:error).with(message)
        expect(notifier).not_to receive(:schedule_payload)

        result = notifier.send(:report, 'info', nil, nil, nil, nil)
        result.should == 'error'
      end

      it 'should be ignored if the person is ignored' do
        person_data = {
          :id => 1,
          :username => 'test',
          :email => 'test@example.com'
        }

        notifier.configure do |config|
          config.ignored_person_ids += [1]
          config.payload_options = { :person => person_data }
        end

        expect(notifier).not_to receive(:schedule_payload)

        result = notifier.send(:report, 'info', 'message', nil, nil, nil)
        result.should == 'ignored'
      end
    end
  end

  context 'reporting' do
    let(:exception) do
      begin
        _foo = bar
      rescue StandardError => e
        e
      end
    end

    let(:logger_mock) { double('Rails.logger').as_null_object }
    let(:user) do
      User.create(:email => 'email@example.com', :encrypted_password => '',
                  :created_at => Time.now, :updated_at => Time.now)
    end

    before do
      Rollbar.unconfigure
      configure

      Rollbar.configure do |config|
        config.logger = logger_mock
      end
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
      Rollbar.clear_notifier!

      Rollbar.configuration.enabled.should be_nil
      Rollbar.error(exception).should == 'disabled'
    end

    it 'should stay disabled if configure is called again' do
      # configure once, setting enabled to false.
      Rollbar.configure do |config|
        config.enabled = false
      end

      # now configure again (perhaps to change some other values)
      Rollbar.configure { |_| }

      Rollbar.configuration.enabled.should eq(false)
      Rollbar.error(exception).should eq('disabled')
    end

    context 'using configuration.use_exception_level_filters_default' do
      before do
        Rollbar.configure do |config|
          config.use_exception_level_filters_default = true
        end
      end

      context 'without use_exception_level_filters argument' do
        it 'sends the correct filtered level' do
          Rollbar.configure do |config|
            config.exception_level_filters = { 'NameError' => 'warning' }
          end

          Rollbar.error(exception)

          expect(Rollbar.last_report[:level]).to be_eql('warning')
        end

        it 'ignore ignored exception classes' do
          Rollbar.configure do |config|
            config.exception_level_filters = { 'NameError' => 'ignore' }
          end

          logger_mock.should_not_receive(:info)
          logger_mock.should_not_receive(:warn)
          logger_mock.should_not_receive(:error)

          Rollbar.error(exception)
        end

        it 'should not use the filters if overriden at log site' do
          Rollbar.configure do |config|
            config.exception_level_filters = { 'NameError' => 'ignore' }
          end

          Rollbar.error(exception, :use_exception_level_filters => false)

          expect(Rollbar.last_report[:level]).to be_eql('error')
        end
      end
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

      it 'sets error level using lambda' do
        Rollbar.configure do |config|
          config.exception_level_filters = {
            'NameError' => lambda { |_error| 'info' }
          }
        end

        logger_mock.should_receive(:info)
        logger_mock.should_not_receive(:warn)
        logger_mock.should_not_receive(:error)

        Rollbar.error(exception, :use_exception_level_filters => true)
      end

      context 'using :use_exception_level_filters option as false' do
        it 'sends the correct filtered level' do
          Rollbar.configure do |config|
            config.exception_level_filters = { 'NameError' => 'warning' }
          end

          Rollbar.error(exception, :use_exception_level_filters => false)
          expect(Rollbar.last_report[:level]).to be_eql('error')
        end

        it 'ignore ignored exception classes' do
          Rollbar.configure do |config|
            config.exception_level_filters = { 'NameError' => 'ignore' }
          end

          Rollbar.error(exception, :use_exception_level_filters => false)

          expect(Rollbar.last_report[:level]).to be_eql('error')
        end
      end
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
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby' && (RUBY_VERSION !~ /^1\.9/)
      it 'should work with an IO object as rack.errors' do
        logger_mock.should_receive(:info).with('[Rollbar] Success')

        Rollbar.error(exception, :env => { :"rack.errors" => IO.new(2, File::WRONLY) })
      end
    end

    it 'should ignore ignored persons' do
      person_data = {
        :id => 1,
        :username => 'test',
        :email => 'test@example.com'
      }

      Rollbar.configure do |config|
        config.payload_options = { :person => person_data }
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
        :username => 'test',
        :email => 'test@example.com'
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
        :username => 'test2',
        :email => 'test2@example.com'
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
      _saved_filters = Rollbar.configuration.exception_level_filters

      Rollbar.configure do |config|
        config.exception_level_filters = { 'NameError' => callable_mock }
      end

      callable_mock.should_receive(:call)
                   .with(exception)
                   .at_least(:once)
                   .and_return('info')
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
      rescue StandardError => e
        Rollbar.error(e)
      end

      test_var.should == 2
    end

    it 'should report exception objects with no backtrace' do
      payload = nil

      notifier.stub(:schedule_item) do |*args|
        payload = args[0]
      end

      Rollbar.error(StandardError.new('oops'))

      payload['data'][:body][:trace][:frames].should eq([])
      payload['data'][:body][:trace][:exception][:class].should eq('StandardError')
      payload['data'][:body][:trace][:exception][:message].should eq('oops')
    end

    it 'gets the backtrace from the caller' do
      Rollbar.configure do |config|
        config.populate_empty_backtraces = true
      end

      exception = Exception.new

      Rollbar.error(exception)

      gem_dir = Gem::Specification.find_by_name('rollbar').gem_dir
      gem_lib_dir = "#{gem_dir}/lib"
      last_report = Rollbar.last_report

      filepaths = last_report[:body][:trace][:frames].map do |frame|
        frame[:filename]
      end.reverse

      expect(filepaths[0]).not_to include(gem_lib_dir)
      expect(filepaths.any? { |filepath| filepath.include?(gem_dir) }).to eq true
    end

    it 'should return the exception data with a uuid, on platforms with SecureRandom' do
      if defined?(SecureRandom) && SecureRandom.respond_to?(:uuid)
        exception_data = Rollbar.error(StandardError.new('oops'))
        exception_data[:uuid].should_not be_nil
      end
    end

    it 'should report exception objects with nonstandard backtraces' do
      payload = nil

      notifier.stub(:schedule_item) do |*args|
        payload = args[0]
      end

      class CustomException < StandardError
        def backtrace
          ['custom backtrace line']
        end
      end

      exception = CustomException.new('oops')

      notifier.error(exception)

      data = payload['data']
      data[:body][:trace][:frames][0][:method].should == 'custom backtrace line'
    end

    it 'should report exceptions with a custom level' do
      payload = nil

      notifier.stub(:schedule_item) do |*args|
        payload = args[0]
      end

      Rollbar.error(exception)

      payload['data'][:level].should eq('error')

      Rollbar.log('debug', exception)

      payload['data'][:level].should eq('debug')
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

    context 'with failsafe error' do
      let(:message) { 'original_error' }
      let(:exception) { StandardError.new(message) }

      it 'should report original error data' do
        allow(Rollbar.notifier)
          .to receive(:build_item)
          .and_raise(StandardError.new('failsafe error'))
        Rollbar.error(exception)

        original_error = Rollbar.last_report[:notifier][:diagnostic][:original_error]
        expect(original_error[:message]).to be_eql(message)
      end

      it 'should report original error stack' do
        allow(Rollbar.notifier)
          .to receive(:build_item)
          .and_raise(StandardError.new('failsafe error'))

        exc_with_stack = nil
        begin
          raise exception
        rescue StandardError => e
          exc_with_stack = e
        end
        Rollbar.error(exc_with_stack)

        original_error = Rollbar.last_report[:notifier][:diagnostic][:original_error]
        expect(original_error[:message]).to be_eql(message)
        expect(original_error[:stack].length).to be > 0
      end

      it 'should report original error data' do
        allow(Rollbar.notifier)
          .to receive(:build_item)
          .and_raise(StandardError.new('failsafe error'))
        Rollbar.error(message)

        original_message = Rollbar.last_report[:notifier][:diagnostic][:original_message]
        expect(original_message).to be_eql(message)
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

    let(:logger_mock) { double('Rails.logger').as_null_object }
    let(:user) do
      User.create(:email => 'email@example.com', :encrypted_password => '',
                  :created_at => Time.now, :updated_at => Time.now)
    end

    it 'should report simple messages' do
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
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
      Rollbar.debug(
        'Test message with extra data',
        'debug',
        :foo => 'bar',
        :hash => { :a => 123, :b => 'xyz' }
      )
    end

    # END Backwards

    it 'should not crash with circular extra_data' do
      a = { :foo => 'bar' }
      b = { :a => a }
      c = { :b => b }
      a[:c] = c # Introduces a cycle

      array1 = %w[a b]
      array2 = ['c', 'd', array1]
      a[:array] = array1

      array1 << array2 # Introduces a cycle

      expect(logger_mock).to_not receive(:error).with(
        /\[Rollbar\] Reporting internal error encountered while sending data to Rollbar./
      )
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      Rollbar.error('Test message with circular extra data', a)
    end

    it 'should be able to report form validation errors when they are present' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      user.errors.add(:example, 'error')
      user.report_validation_errors_to_rollbar
    end

    it 'should not report form validation errors when they are not present' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Success')
      user.errors.clear
      user.report_validation_errors_to_rollbar
    end

    it 'should report messages with extra data' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.info('Test message with extra data', :foo => 'bar',
                                                   :hash => { :a => 123, :b => 'xyz' })
    end

    it 'should report messages with request, person data and extra data' do
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      request_data = {
        :params => { :foo => 'bar' }
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

      Rollbar.info('Test message', extra_data)

      Rollbar.last_report[:request].should eq(request_data)
      Rollbar.last_report[:person].should eq(person_data)
      Rollbar.last_report[:body][:message][:extra][:extra_foo].should eq('extra_bar')
    end
  end

  it 'should scrub the extra field' do
    Rollbar.configure do |config|
      config.scrub_fields |= [:scrubbed_field]
    end

    Rollbar.error('test error', :scrubbed_field => 'sensitive_info')
    Rollbar.last_report[:body][:message][:extra][:scrubbed_field].should match(/^*+$/)
  end

  context 'payload_destination' do
    before(:each) do
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
        config.filepath = 'test.rollbar'
      end
    end

    after do
      configure
    end

    let(:exception) do
      begin
        _foo = bar
      rescue StandardError => e
        e
      end
    end

    let(:logger_mock) { double('Rails.logger').as_null_object }

    it 'should send the payload over the network by default' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Writing payload to file')
      logger_mock.should_receive(:info).with('[Rollbar] Sending item').once
      logger_mock.should_receive(:info).with('[Rollbar] Success').once
      Rollbar.error(exception)
    end

    it 'should save the payload to a file if set without file for each pid' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Sending item')
      logger_mock.should_receive(:info).with('[Rollbar] Writing item to file').once
      logger_mock.should_receive(:info).with('[Rollbar] Success').once

      filepath = ''

      Rollbar.configure do |config|
        config.write_to_file = true
        filepath = config.filepath
      end

      Rollbar.error(exception)

      File.exist?(filepath).should eq(true)
      File.delete(filepath)

      Rollbar.configure do |config|
        config.write_to_file = false
      end
    end

    it 'should save the payload to a file if set with file for each pid' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Sending item')
      logger_mock.should_receive(:info).with('[Rollbar] Writing item to file').once
      logger_mock.should_receive(:info).with('[Rollbar] Success').once

      filepath = ''

      Rollbar.configure do |config|
        config.write_to_file = true
        config.files_with_pid_name_enabled = true

        filepath = config.filepath.gsub(Rollbar::Notifier::EXTENSION_REGEXP,
                                        "_#{Process.pid}\\0")
      end

      Rollbar.error(exception)

      File.exist?(filepath).should eq(true)
      File.delete(filepath)

      Rollbar.configure do |config|
        config.write_to_file = false
        config.files_with_pid_name_enabled = false
      end
    end
  end

  context 'using a proxy server' do
    before do
      allow_any_instance_of(Net::HTTP)
        .to receive(:request)
        .and_return(OpenStruct.new(:code => 200, :body => 'Success'))
      @env_vars = clear_proxy_env_vars
    end

    after do
      restore_proxy_env_vars(@env_vars)
    end

    context 'via environment variables' do
      before do
        @uri = URI.parse(Rollbar::Configuration::DEFAULT_ENDPOINT)
      end

      it 'honors proxy settings in the environment' do
        ENV['http_proxy']  = 'http://user:pass@example.com:80'
        ENV['https_proxy'] = 'http://user:pass@example.com:80'

        expect(Net::HTTP).to receive(:new).with(@uri.host, @uri.port, 'example.com', 80,
                                                'user', 'pass').and_call_original
        Rollbar.info('proxy this')
      end

      it 'does not use a proxy if no proxy settings in environemnt' do
        expect(Net::HTTP).to receive(:new).with(@uri.host, @uri.port, nil, nil, nil,
                                                nil).and_call_original
        Rollbar.info('proxy this')
      end
    end

    context 'set in configuration file' do
      before do
        Rollbar.configure do |config|
          config.proxy = {
            :host => 'http://config.com',
            :port => 8080,
            :user => 'foo',
            :password => 'bar'
          }
        end

        @uri = URI.parse(Rollbar::Configuration::DEFAULT_ENDPOINT)
      end

      it 'honors proxy settings in the config file' do
        expect(Net::HTTP).to receive(:new).with(@uri.host, @uri.port, 'config.com', 8080,
                                                'foo', 'bar').and_call_original
        Rollbar.info('proxy this')
      end

      it 'gives the configuration settings precedence over environment' do
        ENV['http_proxy']  = 'http://user:pass@example.com:80'
        ENV['https_proxy'] = 'http://user:pass@example.com:80'

        expect(Net::HTTP).to receive(:new).with(@uri.host, @uri.port, 'config.com', 8080,
                                                'foo', 'bar').and_call_original
        Rollbar.info('proxy this')
      end

      it 'allows @-signs in passwords' do
        Rollbar.configure do |config|
          config.proxy[:password] = 'manh@tan'
        end

        expect(Net::HTTP).to receive(:new).with(@uri.host, @uri.port, 'config.com', 8080,
                                                'foo', 'manh@tan').and_call_original
        Rollbar.info('proxy this')
      end
    end
  end

  context 'asynchronous_handling' do
    before do
      Rollbar.clear_notifier!
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
      end
    end

    after do
      configure
    end

    let(:exception) do
      begin
        _foo = bar
      rescue StandardError => e
        e
      end
    end

    let(:logger_mock) { double('Rails.logger').as_null_object }

    it 'should send the payload using the default asynchronous handler girl_friday' do
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
      logger_mock.should_receive(:info).with('[Rollbar] Sending item')
      logger_mock.should_receive(:info).with('[Rollbar] Sending json')
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
      logger_mock.should_receive(:info).with('[Rollbar] Sending item')
      logger_mock.should_receive(:info).with('[Rollbar] Sending json')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      Rollbar.configure do |config|
        config.use_async = true
        config.async_handler = proc { |payload|
          logger_mock.info 'Custom async handler called'
          Rollbar.process_from_async_handler(payload)
        }
      end

      Rollbar.error(exception)
    end

    it 'should send the payload as a json string when async_object_payload is false' do
      logger_mock.should_receive(:info).with('payload class: String')
      logger_mock.should_receive(:info).with('[Rollbar] Sending json')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      Rollbar.configure do |config|
        config.use_async = true
        config.async_json_payload = true
        config.async_handler = proc { |payload|
          logger_mock.info "payload class: #{payload.class}"
          Rollbar.process_from_async_handler(payload)
        }
      end

      Rollbar.error(exception)

      Rollbar.configure do |config|
        config.use_async = false
        config.async_json_payload = false
      end
    end

    it 'should send without configured_options when async_json_payload is not set',
       :if => Gem.loaded_specs['activesupport'].version >= Gem::Version.new('4.1') do
      # Verify no configured_options
      logger_mock.should_receive(:info)
                 .with('not serialized when async_json_payload is not set')

      # Verify payload is received as a hash and converted to json.
      logger_mock.should_receive(:info).with('payload class: Hash')
      logger_mock.should_receive(:info).with('[Rollbar] Sending item')
      logger_mock.should_receive(:info).with('[Rollbar] Sending json')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      Rollbar.configure do |config|
        config.use_async = true
        config.async_handler = proc { |payload|
          logger_mock.info "payload class: #{payload.class}"
          logger_mock.info payload['data'][:notifier][:configured_options]
          Rollbar.process_from_async_handler(payload)
        }
      end

      Rollbar.error(exception)

      Rollbar.configure do |config|
        config.use_async = false
      end
    end

    # We should be able to send String payloads, generated
    # by a previous version of the gem. This can happend just
    # after a deploy with an gem upgrade.
    context 'with a payload generated as String' do
      let(:async_handler) do
        proc do |payload|
          # simulate previous gem version
          string_payload = Rollbar::JSON.dump(payload)

          Rollbar.process_from_async_handler(string_payload)
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
            config.access_token = test_access_token
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
          let(:async_handler) { proc { |_| raise 'this handler will crash' } }

          context 'if any failover handlers is configured' do
            let(:handlers) { [] }
            let(:log_message) do
              '[Rollbar] Async handler failed, and there are no failover ' \
              'handlers configured. See the docs for "failover_handlers"'
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
            let(:handler1) { proc { |_| raise 'this handler fails' } }
            let(:handler2) { proc { |_| 'success' } }
            let(:handlers) { [handler1, handler2] }

            it 'calls the second handler and doesnt report internal error' do
              expect(handler2).to receive(:call)

              Rollbar.error(exception)
            end
          end

          context 'with two handlers, both failing' do
            let(:handler1) { proc { |_| raise 'this handler fails' } }
            let(:handler2) { proc { |_| raise 'this will also fail' } }
            let(:handlers) { [handler1, handler2] }

            it 'reports internal error' do
              expect(logger_mock).to receive(:error)

              Rollbar.error(exception)
            end
          end
        end
      end
    end

    describe '#use_sucker_punch', :if => defined?(SuckerPunch) do
      it 'should send the payload to sucker_punch delayer' do
        logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
        expect(Rollbar::Delay::SuckerPunch).to receive(:call)

        Rollbar.configure(&:use_sucker_punch)
        Rollbar.error(exception)
      end
    end

    describe '#use_shoryuken', :if => defined?(Shoryuken) do
      it 'should send the payload to shoryuken delayer' do
        logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
        expect(Rollbar::Delay::Shoryuken).to receive(:call)

        Rollbar.configure(&:use_shoryuken)
        Rollbar.error(exception)
      end
    end

    describe '#use_sidekiq', :if => defined?(Sidekiq) do
      it 'should instanciate sidekiq delayer with custom values' do
        Rollbar::Delay::Sidekiq.should_receive(:new).with('queue' => 'test_queue')
        config = Rollbar::Configuration.new
        config.use_sidekiq 'queue' => 'test_queue'
      end

      it 'should send the payload to sidekiq delayer' do
        handler = double('sidekiq_handler_mock')
        handler.should_receive(:call)

        Rollbar.configure do |config|
          config.use_sidekiq
          config.async_handler = handler
        end

        Rollbar.error(exception)
      end
    end

    describe '#use_thread' do
      let(:payload) { { :key => 'value' } }
      let(:custom_priority) { 3 }

      it 'should send with default priority' do
        expect(Rollbar).to receive(:process_from_async_handler).with(payload)

        # Reset state before Rollbar.configure
        Rollbar::Delay::Thread.options = nil

        Rollbar.configure do |config|
          config.use_thread
        end

        thread = Rollbar::Delay::Thread.call(payload)
        sleep(1) # More reliable than Thread.pass to let the thread set its priority.
        expect(thread.priority).to eq(Rollbar::Delay::Thread::DEFAULT_PRIORITY)
        thread.join
      end

      it 'should send with configured priority' do
        expect(Rollbar).to receive(:process_from_async_handler).with(payload)

        # Reset state before Rollbar.configure
        Rollbar::Delay::Thread.options = nil

        Rollbar.configure do |config|
          config.use_thread({ :priority => custom_priority })
        end

        thread = Rollbar::Delay::Thread.call(payload)
        sleep(1) # More reliable than Thread.pass to let the thread set its priority.
        expect(thread.priority).to eq(custom_priority)
        thread.join
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
      logger = Logger.new($stderr)

      Rollbar.configure do |config|
        config.default_logger = lambda { logger }
      end

      Rollbar.send(:logger).object.should == logger
    end

    it 'should have a default default_logger' do
      Rollbar.send(:logger).should_not be_nil
    end

    after do
      reset_configuration
    end
  end

  context 'project_gems' do
    it 'should include gem paths for specified project gems in the payload' do
      gems = %w[rack rspec-rails]
      gem_paths = []

      Rollbar.configure do |config|
        config.project_gems = gems
      end

      gem_paths = gems.map do |gem|
        gem_spec = Gem::Specification.find_all_by_name(gem)[0]
        gem_spec.gem_dir if gem_spec
      end.compact

      data = notifier.send(:build_item, 'info', 'test', nil, {}, nil)['data']
      data[:project_package_paths].is_a?(Array).should eq(true)
      data[:project_package_paths].length.should eq(gem_paths.length)

      data[:project_package_paths].each_with_index do |path, index|
        path.should == gem_paths[index]
      end
    end

    it 'should handle regex gem patterns' do
      gems = ['rack', /rspec/, /roll/]

      Rollbar.configure do |config|
        config.project_gems = gems
      end

      gem_paths = gems.map do |name|
        Gem::Specification.each.select { |spec| name === spec.name }
      end.flatten.uniq.map(&:gem_dir)

      gem_paths.length.should be > 1

      gem_paths.any? { |path| path.include? 'rollbar-gem' }.should eq(true)
      gem_paths.any? { |path| path.include? 'rspec-rails' }.should eq(true)

      data = notifier.send(:build_item, 'info', 'test', nil, {}, nil)['data']
      data[:project_package_paths].is_a?(Array).should eq(true)
      data[:project_package_paths].length.should eq(gem_paths.length)
      (data[:project_package_paths] - gem_paths).length.should eq(0)
    end

    it 'should not break on non-existent gems' do
      gems = %w[this_gem_does_not_exist rack]

      Rollbar.configure do |config|
        config.project_gems = gems
      end

      data = notifier.send(:build_item, 'info', 'test', nil, {}, nil)['data']
      data[:project_package_paths].is_a?(Array).should eq(true)
      data[:project_package_paths].length.should eq(1)
    end
  end

  context 'report_internal_error', :reconfigure_notifier => true do
    it 'should not crash when given an exception object' do
      begin
        1 / 0
      rescue StandardError => e
        notifier.send(:report_internal_error, e)
      end
    end
  end

  context 'send_failsafe' do
    let(:exception) { StandardError.new }

    it "doesn't crash when given a message and exception" do
      sent_payload = notifier.send(:send_failsafe, 'test failsafe', exception)

      expected_message = 'Failsafe from rollbar-gem. StandardError: test failsafe'
      expect(sent_payload['data'][:body][:message][:body]).to be_eql(expected_message)
    end

    it "doesn't crash when given all nils" do
      notifier.send(:send_failsafe, nil, nil)
    end

    context 'with a non default exception message' do
      let(:exception) { StandardError.new 'Something is wrong' }

      it 'adds it to exception info' do
        sent_payload = notifier.send(:send_failsafe, 'test failsafe', exception)

        expected_message = \
          'Failsafe from rollbar-gem. StandardError: "Something is wrong": test failsafe'
        expect(sent_payload['data'][:body][:message][:body]).to be_eql(expected_message)
      end
    end

    context 'without exception object' do
      it 'just sends the given message' do
        sent_payload = notifier.send(:send_failsafe, 'test failsafe', nil)

        expected_message = 'Failsafe from rollbar-gem. test failsafe'
        expect(sent_payload['data'][:body][:message][:body]).to be_eql(expected_message)
      end
    end

    context 'if the exception has a backtrace' do
      let(:backtrace) { %w[func3 func2 func1] }
      let(:failsafe_reason) { 'StandardError in func3: test failsafe' }
      let(:expected_body) { "Failsafe from rollbar-gem. #{failsafe_reason}" }
      let(:expected_log_message) do
        "[Rollbar] Sending failsafe response due to #{failsafe_reason}"
      end

      before { exception.set_backtrace(backtrace) }

      it 'adds the nearest frame to the message' do
        expect(notifier).to receive(:log_error).with(expected_log_message)

        sent_payload = notifier.send(:send_failsafe, 'test failsafe', exception)

        expect(sent_payload['data'][:body][:message][:body]).to be_eql(expected_body)
      end
    end

    context 'with uuid and host' do
      let(:host) { 'the-host' }
      let(:uuid) { 'the-uuid' }
      it 'sets the uuid and host in correct keys' do
        original_error = {
          :uuid => uuid,
          :host => host
        }

        sent_payload = notifier.send(:send_failsafe, 'testing uuid and host',
                                     exception, original_error)

        diagnostic = sent_payload['data'][:notifier][:diagnostic]
        expect(diagnostic[:original_uuid]).to be_eql('the-uuid')
        expect(diagnostic[:original_host]).to be_eql('the-host')
      end
    end
  end

  context 'when reporting internal error with nil context' do
    let(:context_proc) { proc {} }
    let(:scoped_notifier) { notifier.scope(:context => context_proc) }
    let(:exception) { Exception.new }
    let(:logger_mock) { double('Rails.logger').as_null_object }

    it 'reports successfully' do
      configure

      Rollbar.configure do |config|
        config.logger = logger_mock
      end

      logger_mock.should_receive(:info).with('[Rollbar] Sending item').once
      logger_mock.should_receive(:info).with('[Rollbar] Success').once
      scoped_notifier.send(:report_internal_error, exception)
    end
  end

  context 'request_data_extractor' do
    before(:each) do
      class DummyClass
      end
      @dummy_class = DummyClass.new
      @dummy_class.extend(Rollbar::RequestDataExtractor)
    end

    context 'rollbar_headers' do
      it 'should not include cookies' do
        env = { 'HTTP_USER_AGENT' => 'test', 'HTTP_COOKIE' => 'cookie' }
        headers = @dummy_class.send(:rollbar_headers, env)
        headers.should have_key 'User-Agent'
        headers.should_not have_key 'Cookie'
      end
    end
  end

  describe '.scoped' do
    let(:scope_options) do
      { :foo => 'bar' }
    end

    it 'changes data in scope_object inside the block' do
      Rollbar.clear_notifier!
      configure

      current_notifier_id = Rollbar.notifier.object_id

      Rollbar.scoped(scope_options) do
        scope_object = Rollbar.notifier.scope_object

        expect(Rollbar.notifier.object_id).not_to be_eql(current_notifier_id)
        expect(scope_object).to be_eql(scope_options)
      end

      expect(Rollbar.notifier.object_id).to be_eql(current_notifier_id)
    end

    context 'if the block fails' do
      let(:crashing_block) { proc { raise } }

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
            scope = Rollbar.notifier.scope_object
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
      scope_object = Rollbar.notifier.scope_object
      Rollbar.scope!(new_scope)

      expect(scope_object).to be_eql(new_scope)
    end
  end

  describe '.clear_notifier' do
    before { Rollbar.notifier }

    it 'resets the notifier' do
      Rollbar.clear_notifier!
      expect(Rollbar.instance_variable_get('@notifier')).to be_nil
      expect(Rollbar.instance_variable_get('@root_notifier')).to be_nil
    end
  end

  describe '.process_item' do
    context 'if there is an exception sending the payload' do
      let(:exception) { StandardError.new('error message') }
      let(:payload) { Rollbar::Item.build_with(:foo => :bar) }

      it 'logs the error and the payload' do
        allow(Rollbar.notifier).to receive(:send_item).and_raise(exception)
        expect(Rollbar.notifier).to receive(:log_error)

        expect { Rollbar.notifier.process_item(payload) }.to raise_error(exception)
      end
    end
  end

  describe '.process_from_async_handler' do
    context 'with errors' do
      let(:exception) { StandardError.new('the error') }

      it 'raises anything and sends internal error' do
        allow(Rollbar.notifier).to receive(:process_item).and_raise(exception)
        expect(Rollbar.notifier).to receive(:report_internal_error).with(exception)

        expect do
          Rollbar.notifier.process_from_async_handler({})
        end.to raise_error(exception)

        rollbar_do_not_report = exception.instance_variable_get(:@_rollbar_do_not_report)
        expect(rollbar_do_not_report).to be_eql(true)
      end
    end
  end

  describe '.preconfigure' do
    before do
      Rollbar.clear_notifier!
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

  context 'having timeout issues' do
    let(:exception_class) do
      Rollbar::LanguageSupport.timeout_exceptions.first
    end
    let(:net_exception) do
      exception_class.new
    end

    before do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(net_exception)
    end

    it 'retries the request' do
      expect_any_instance_of(Net::HTTP).to receive(:request).exactly(3)
      expect(Rollbar.notifier).to receive(:report_internal_error).with(net_exception,
                                                                       anything)

      Rollbar.info('foo')
    end
  end

  describe '.with_config' do
    let(:new_config) do
      { 'environment' => 'foo' }
    end

    it 'uses the new config and restores the old one' do
      config1 = described_class.configuration

      subject.with_config(:environment => 'bar') do
        expect(described_class.configuration).not_to be(config1)
      end

      expect(described_class.configuration).to be(config1)
    end
  end

  # configure with some basic params
  def configure
    reconfigure_notifier
  end
end
