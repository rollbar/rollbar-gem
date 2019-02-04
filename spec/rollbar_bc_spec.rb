# encoding: UTF-8

require 'logger'
require 'spec_helper'

describe Rollbar do
  let(:notifier) { Rollbar.notifier }

  context 'bc_report_message' do
    before do
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
      end
    end

    let(:logger_mock) { double('Rails.logger').as_null_object }
    let(:user) do
      User.create(:email => 'email@example.com',
                  :encrypted_password => '',
                  :created_at => Time.now,
                  :updated_at => Time.now)
    end

    it 'should report simple messages' do
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      Rollbar.report_message('Test message')
    end

    it 'should not report anything when disabled' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Success')

      Rollbar.configure do |config|
        config.enabled = false
      end

      Rollbar.report_message('Test message that should be ignored')
    end

    it 'should report messages with extra data' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.report_message('Test message with extra data', 'debug', :foo => 'bar',
                               :hash => { :a => 123, :b => 'xyz' })
    end

    it 'should not crash with circular extra_data' do
      a = { :foo => 'bar' }
      b = { :a => a }
      c = { :b => b }
      a[:c] = c

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
  end

  context 'bc_report_message_with_request' do
    before(:each) do
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
      end
    end

    after do
      Rollbar.unconfigure
      configure
    end

    let(:logger_mock) { double('Rails.logger').as_null_object }
    let(:user) { User.create(:email => 'email@example.com', :encrypted_password => '', :created_at => Time.now, :updated_at => Time.now) }

    it 'should report simple messages' do
      allow(Rollbar).to receive(:notifier).and_return(notifier)
      logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.report_message_with_request('Test message')

      Rollbar.last_report[:request].should be_nil
      Rollbar.last_report[:person].should be_nil
    end

    it 'should report messages with request, person data and extra data' do
      Rollbar.last_report = nil

      logger_mock.should_receive(:info).with('[Rollbar] Scheduling item')
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

      Rollbar.report_message_with_request('Test message', 'info', request_data, person_data, extra_data)

      Rollbar.last_report[:request].should == request_data
      Rollbar.last_report[:person].should == person_data
      Rollbar.last_report[:body][:message][:extra][:extra_foo].should == 'extra_bar'
    end
  end

  context 'bc_report_exception' do
    before(:each) do
      configure
      Rollbar.configure do |config|
        config.logger = logger_mock
      end

      begin
        foo = bar
      rescue => e
        @exception = e
      end
    end

    after do
      Rollbar.unconfigure
      configure
    end

    let(:logger_mock) { double('Rails.logger').as_null_object }

    it 'should report exceptions without person or request data' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      Rollbar.report_exception(@exception)
    end

    it 'should not report anything when disabled' do
      logger_mock.should_not_receive(:info).with('[Rollbar] Success')
      Rollbar.configure do |config|
        config.enabled = false
      end

      Rollbar.report_exception(@exception)
    end

    it 'should be enabled when freshly configured' do
      Rollbar.configuration.enabled.should == true
    end

    it 'should not be enabled when not configured' do
      Rollbar.clear_notifier!

      Rollbar.configuration.enabled.should be_nil
      Rollbar.report_exception(@exception).should == 'disabled'
    end

    it 'should stay disabled if configure is called again' do
      Rollbar.clear_notifier!

      # configure once, setting enabled to false.
      Rollbar.configure do |config|
        config.enabled = false
      end

      # now configure again (perhaps to change some other values)
      Rollbar.configure do |config| end

      Rollbar.configuration.enabled.should == false
      Rollbar.report_exception(@exception).should == 'disabled'
    end

    it 'should report exceptions with request and person data' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      request_data = {
        :params => { :foo => 'bar' },
        :url => 'http://localhost/',
        :user_ip => '127.0.0.1',
        :headers => {},
        :GET => { 'baz' => 'boz' },
        :session => { :user_id => 123 },
        :method => 'GET',
      }
      person_data = {
        :id => 1,
        :username => 'test',
        :email => 'test@example.com'
      }
      Rollbar.report_exception(@exception, request_data, person_data)
    end

    # Skip jruby 1.9+ (https://github.com/jruby/jruby/issues/2373)
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby' && (not RUBY_VERSION =~ /^1\.9/)
      it 'should work with an IO object as rack.errors' do
        logger_mock.should_receive(:info).with('[Rollbar] Success')

        request_data = {
          :params => { :foo => 'bar' },
          :url => 'http://localhost/',
          :user_ip => '127.0.0.1',
          :headers => {},
          :GET => { 'baz' => 'boz' },
          :session => { :user_id => 123 },
          :method => 'GET',
          :env => { :'rack.errors' => IO.new(2, File::WRONLY) },
        }

        person_data = {
          :id => 1,
          :username => 'test',
          :email => 'test@example.com'
        }

        Rollbar.report_exception(@exception, request_data, person_data)
      end
    end

    it 'should ignore ignored exception classes' do
      Rollbar.configure do |config|
        config.exception_level_filters = { 'NameError' => 'ignore' }
      end

      logger_mock.should_not_receive(:info)
      logger_mock.should_not_receive(:error)

      Rollbar.report_exception(@exception)
    end

    it 'should ignore ignored persons' do
      Rollbar.configure do |config|
        config.ignored_person_ids += [1]
      end

      logger_mock.should_not_receive(:info)
      logger_mock.should_not_receive(:error)

      person_data = {
        :id => 1,
        :username => 'test',
        :email => 'test@example.com'
      }
      Rollbar.report_exception(@exception, {}, person_data)
    end

    it 'should not ignore non-ignored persons' do
      Rollbar.configure do |config|
        config.ignored_person_ids += [1]
      end

      Rollbar.last_report = nil

      person_data = {
        :id => 1,
        :username => 'test',
        :email => 'test@example.com'
      }
      Rollbar.report_exception(@exception, {}, person_data)
      Rollbar.last_report.should be_nil

      person_data = {
        :id => 2,
        :username => 'test2',
        :email => 'test2@example.com'
      }
      Rollbar.report_exception(@exception, {}, person_data)
      Rollbar.last_report.should_not be_nil
    end

    it 'should allow callables to set exception filtered level with :use_exception_level_filters option' do
      callable_mock = double
      Rollbar.configure do |config|
        config.exception_level_filters = { 'NameError' => callable_mock }
      end

      callable_mock.should_receive(:call).with(@exception).at_least(:once).and_return('info')
      logger_mock.should_receive(:info)
      logger_mock.should_not_receive(:error)

      Rollbar.report_exception(@exception)
    end

    it 'should not report exceptions when silenced' do
      notifier.should_not_receive :schedule_payload

      begin
        test_var = 1
        Rollbar.silenced do
          test_var = 2
          raise
        end
      rescue => e
        Rollbar.report_exception(e)
      end

      test_var.should == 2
    end

    it 'should report exception objects with no backtrace' do
      allow(Rollbar).to receive(:notifier).and_return(notifier)

      payload = nil

      notifier.stub(:schedule_item) do |*args|
        payload = args[0]
      end

      Rollbar.report_exception(StandardError.new('oops'))

      payload['data'][:body][:trace][:frames].should == []
      payload['data'][:body][:trace][:exception][:class].should == 'StandardError'
      payload['data'][:body][:trace][:exception][:message].should == 'oops'
    end

    it 'should return the exception data with a uuid, on platforms with SecureRandom' do
      if defined?(SecureRandom) and SecureRandom.respond_to?(:uuid)
        notifier.stub(:schedule_payload) do |*args| end

        exception_data = Rollbar.report_exception(StandardError.new('oops'))
        exception_data[:uuid].should_not be_nil
      end
    end

    it 'should report exception objects with nonstandard backtraces' do
      allow(Rollbar).to receive(:notifier).and_return(notifier)

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

      Rollbar.report_exception(exception)

      payload['data'][:body][:trace][:frames][0][:method].should == 'custom backtrace line'
    end

    it 'should report exceptions with a custom level' do
      allow(Rollbar).to receive(:notifier).and_return(notifier)
      payload = nil

      notifier.stub(:schedule_item) do |*args|
        payload = args[0]
      end

      Rollbar.report_exception(@exception)

      payload['data'][:level].should == 'error'

      Rollbar.report_exception(@exception, nil, nil, 'debug')

      payload['data'][:level].should == 'debug'
    end
  end

  # configure with some basic params
  def configure
    reconfigure_notifier
  end
end
