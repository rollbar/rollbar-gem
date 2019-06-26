require 'spec_helper'

def wrap_process_args(*args)
  if ::Gem::Version.new(::Rails.version) >= ::Gem::Version.new('5.0')
    [{ :params => args[0], :headers => args[1] }]
  else
    args
  end
end

describe HomeController do
  let(:logger_mock) { double('Rails.logger').as_null_object }
  let(:notifier) { Rollbar.notifier }

  before do
    Rollbar.clear_notifier!
    reset_configuration
    preconfigure_rails_notifier

    Rollbar.configure do |config|
      config.access_token = test_access_token
      config.logger = logger_mock
      config.open_timeout = 60
      config.request_timeout = 60
    end
  end

  context 'rollbar base_data' do
    it 'should have the Rails environment' do
      data = Rollbar.notifier.send(:build_item, 'error', 'message', nil, nil, nil)
      data['data'][:environment].should eq(::Rails.env)
    end

    it 'should have an overridden environment' do
      Rollbar.configure do |config|
        config.environment = 'dev'
      end

      data = Rollbar.notifier.send(:build_item, 'error', 'message', nil, nil, nil)
      data['data'][:environment].should eq('dev')
    end

    it 'should use the default "unspecified" environment if rails env ends up being empty' do
      old_env = ::Rails.env
      ::Rails.env = ''
      preconfigure_rails_notifier

      data = Rollbar.notifier.send(:build_item, 'error', 'message', nil, nil, nil)
      data['data'][:environment].should eq('unspecified')

      ::Rails.env = old_env
    end
  end

  context format('rollbar controller methods with %s requests', (local? ? 'local' : 'non-local')) do
    # TODO: run these for a a more-real request
    it 'should build valid request data' do
      data = @controller.rollbar_request_data
      data.should have_key(:params)
      data.should have_key(:url)
      data.should have_key(:user_ip)
      data.should have_key(:headers)
      data.should have_key(:session)
      data.should have_key(:method)
    end

    it 'should build empty person data when no one is logged-in' do
      data = @controller.rollbar_person_data
      data.should == {}
    end

    context 'rollbar_scrub_headers' do
      it 'should filter authentication by default' do
        headers = {
          'HTTP_AUTHORIZATION' => 'some-user',
          'HTTP_USER_AGENT' => 'spec'
        }

        filtered = controller.send(:rollbar_headers, headers)

        expect(filtered['Authorization']).to match(/\**/)
        expect(filtered['User-Agent']).to be_eql('spec')
      end

      it 'should filter custom headers' do
        Rollbar.configure do |config|
          config.scrub_headers = %w[Auth Token]
        end

        headers = {
          'HTTP_AUTH' => 'auth-value',
          'HTTP_TOKEN' => 'token-value',
          'HTTP_CONTENT_TYPE' => 'text/html'
        }

        filtered = controller.send(:rollbar_headers, headers)
        expect(filtered['Auth']).to match(/\**/)
        expect(filtered['Token']).to match(/\**/)
        expect(filtered['Content-Type']).to be_eql('text/html')
      end
    end

    context 'rollbar_request_url' do
      it 'should build simple http urls' do
        req = controller.request
        req.host = 'rollbar.com'

        controller.send(:rollbar_request_data)[:url].should eq('http://rollbar.com')
      end

      it 'should respect forwarded host' do
        req = controller.request
        req.host = '127.0.0.1:8080'
        req.env['HTTP_X_FORWARDED_HOST'] = 'test.com'

        controller.send(:rollbar_request_data)[:url].should eq('http://test.com')
      end

      it 'should respect forwarded proto' do
        req = controller.request
        req.host = 'rollbar.com'
        req.env['HTTP_X_FORWARDED_PROTO'] = 'https'

        controller.send(:rollbar_request_data)[:url].should eq('https://rollbar.com')
      end

      it 'should respect forwarded port' do
        req = controller.request
        req.host = '127.0.0.1:8080'
        req.env['HTTP_X_FORWARDED_HOST'] = 'test.com'
        req.env['HTTP_X_FORWARDED_PORT'] = '80'

        controller.send(:rollbar_request_data)[:url].should eq('http://test.com')

        req.env['HTTP_X_FORWARDED_PORT'] = '81'
        controller.send(:rollbar_request_data)[:url].should eq('http://test.com:81')
      end
    end

    context 'rollbar_user_ip' do
      it 'should use X-Real-Ip when set' do
        controller.request.env['HTTP_X_REAL_IP'] = '1.1.1.1'
        controller.request.env['HTTP_X_FORWARDED_FOR'] = '1.2.3.4'
        controller.send(:rollbar_request_data)[:user_ip].should eq('1.1.1.1')
      end

      it 'should use X-Forwarded-For when set' do
        controller.request.env['HTTP_X_FORWARDED_FOR'] = '1.2.3.4'
        controller.send(:rollbar_request_data)[:user_ip].should eq('1.2.3.4')
      end

      it 'should use the remote_addr when neither is set' do
        controller.send(:rollbar_request_data)[:user_ip].should eq('0.0.0.0')
      end

      context 'rollbar_user_ip obfuscator' do
        before do
          Rollbar.configure do |config|
            config.user_ip_obfuscator_secret = 'secret'
          end
        end

        it 'should obfuscate the ip when user_ip_obfuscator_secret is set' do
          real_ip = '1.1.1.1'
          obfuscated_ip = '95.191.35.149'
          controller.request.env['HTTP_X_REAL_IP'] = real_ip
          controller.send(:rollbar_request_data)[:user_ip].should eq(obfuscated_ip)
        end

        it 'should clear the ip field when an invalid ip is provided' do
          invalid_ip = '1.1.1.999'
          controller.request.env['HTTP_X_REAL_IP'] = invalid_ip
          controller.send(:rollbar_request_data)[:user_ip].should.nil?
        end
      end
    end

    context 'rollbar_route_params', :type => 'request' do
      it 'should save controller and action in the payload body' do
        post '/report_exception'

        route = controller.send(:rollbar_request_data)[:params]

        route[:controller].should eq('home')
        route[:action].should eq('report_exception')

        Rollbar.last_report.should_not be_nil
        Rollbar.last_report[:context].should eq('home#report_exception')
      end
    end
  end

  context 'param_scrubbing', :type => 'request' do
    it 'should scrub the default scrub_fields' do
      params = {
        :passwd => 'hidden',
        :password => 'hidden',
        :secret => 'hidden',
        :notpass => 'visible',
        :secret_token => 'f6805fea1cae0fb79c5e63bbdcd12bc6'
      }

      post '/report_exception', *wrap_process_args(params)

      filtered = Rollbar.last_report[:request][:POST]

      expect(filtered['passwd']).to match(/\**/)
      expect(filtered['password']).to match(/\**/)
      expect(filtered['secret']).to match(/\**/)
      expect(filtered['notpass']).to match(/\**/)
      expect(filtered['secret_token']).to match(/\**/)
    end

    it 'should scrub custom scrub_fields' do
      Rollbar.configure do |config|
        config.scrub_fields = [:notpass, :secret]
      end

      params = {
        :passwd => 'visible',
        :password => 'visible',
        :secret => 'hidden',
        :notpass => 'hidden'
      }

      post '/report_exception', *wrap_process_args(params)

      filtered = Rollbar.last_report[:request][:POST]

      filtered['passwd'].should eq('visible')
      # config.filter_parameters is set to [:password] in
      # spec/dummyapp/config/application.rb
      expect(filtered['password']).to match(/\**/)
      expect(filtered['secret']).to match(/\**/)
      expect(filtered['notpass']).to match(/\**/)
    end
  end

  describe "GET 'index'" do
    it 'should be successful and report two messages' do
      logger_mock.should_receive(:info).with('[Rollbar] Success').twice
      get 'index'
      expect(response.status).to eq(200)
    end
  end

  describe "'report_exception'", :type => 'request' do
    it 'should raise a NameError and report an exception after a GET' do
      logger_mock.should_receive(:info).with('[Rollbar] Success').once

      get '/report_exception'
      expect(response.status).to eq(200)
    end

    it 'should raise a NameError and have PUT params in the reported exception' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')

      put '/report_exception', *wrap_process_args(:putparam => 'putval')

      Rollbar.last_report.should_not be_nil
      Rollbar.last_report[:request][:POST]['putparam'].should == 'putval'
    end

    context 'using deprecated report_exception' do
      it 'reports the errors successfully' do
        logger_mock.should_receive(:info).with('[Rollbar] Success')

        put '/deprecated_report_exception', *wrap_process_args(:putparam => 'putval')

        Rollbar.last_report.should_not be_nil
        Rollbar.last_report[:request][:POST]['putparam'].should == 'putval'
      end
    end

    it 'should raise a NameError and have JSON POST params' do
      logger_mock.should_receive(:info).with('[Rollbar] Success')
      @request.env['HTTP_ACCEPT'] = 'application/json'

      params = { :jsonparam => 'jsonval' }.to_json
      post '/report_exception', *wrap_process_args(params, 'CONTENT_TYPE' => 'application/json')

      Rollbar.last_report.should_not be_nil
      expect(Rollbar.last_report[:request][:body]).to be_eql(params)
    end
  end

  describe 'configuration.locals', :type => 'request',
                                   :if => RUBY_VERSION >= '2.3.0' &&
                                          !(defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby') do
    context 'when locals is enabled' do
      before do
        Rollbar.configure do |config|
          config.send_extra_frame_data = :all
          config.locals = { :enabled => true }
          config.randomize_scrub_length = false
        end
      end

      let(:locals) do
        [
          {
            :obj => 'Post',
            :password => '******',
            :hash => "{:foo=>Post, :bar=>\"bar\"}", # rubocop:disable Style/StringLiterals
            :foo => 'Post',
            :_index => '0'
          },
          {
            :foo => 'Post', :_index => '0'
          },
          {
            :foo => 'Post', :_index => '0'
          },
          {
            :foo => 'Post', :index => '0'
          },
          {
            :foo => 'Post'
          }
        ]
      end

      it 'should include locals in extra data' do
        logger_mock.should_receive(:info).with('[Rollbar] Success').once

        expect { get '/cause_exception_with_locals' }.to raise_exception(NoMethodError)

        frames = Rollbar.last_report[:body][:trace][:frames]

        expect(frames[-1][:locals]).to be_eql(locals[0])
        expect(frames[-2][:locals]).to be_eql(locals[1])
        expect(frames[-3][:locals]).to be_eql(locals[2])
        expect(frames[-4][:locals]).to be_eql(locals[3])
        # Frames: -5, -6 are not app frames, and have different contents in
        # different Ruby versions.
        expect(frames[-7][:locals]).to be_eql(locals[4])
      end
    end

    context 'when locals is not enabled' do
      before do
        Rollbar.configure do |config|
          config.send_extra_frame_data = :app
        end
      end

      it 'should not include locals in extra data' do
        logger_mock.should_receive(:info).with('[Rollbar] Success').once

        expect { get '/cause_exception_with_locals' }.to raise_exception(NoMethodError)
        expect(Rollbar.last_report[:body][:trace][:frames][-1][:locals]).to be_eql({})
      end
    end
  end

  describe "'cause_exception'", :type => 'request' do
    it 'should raise an uncaught exception and report a message' do
      logger_mock.should_receive(:info).with('[Rollbar] Success').once

      expect { get '/cause_exception' }.to raise_exception(NameError)
    end

    context 'with capture_uncaught == false' do
      it 'should not report the exception' do
        Rollbar.configure do |config|
          config.capture_uncaught = false
        end

        expect(Rollbar).to_not receive(:log)

        expect { get '/cause_exception' }.to raise_exception(NameError)
      end
    end

    context 'show_exceptions' do
      before(:each) do
        config = if Dummy::Application.respond_to? :env_config
                   Dummy::Application.env_config
                 else
                   Dummy::Application.env_defaults
                 end

        config['action_dispatch.show_exceptions'] = true
      end

      after do
        config = if Dummy::Application.respond_to? :env_config
                   Dummy::Application.env_config
                 else
                   Dummy::Application.env_defaults
                 end

        config['action_dispatch.show_exceptions'] = false
      end

      it 'middleware should catch the exception and only report to rollbar once' do
        logger_mock.should_receive(:info).with('[Rollbar] Success').once

        get '/cause_exception'
      end

      it 'should not fail if the controller doesnt contain the person method' do
        Rollbar.configure do |config|
          config.person_method = 'invalid_method'
        end

        get '/cause_exception'
      end

      it 'should detect and stop recursion in the person method' do
        Rollbar.configure do |config|
          config.person_method = 'recursive_current_user'
        end

        get '/cause_exception'
      end

      context 'with logged user' do
        let(:user) do
          User.create(:email => 'foo@bar.com',
                      :username => 'the_username')
        end

        before { cookies[:session_id] = user.id }

        subject(:person_data) do
          put '/report_exception', *wrap_process_args('foo' => 'bar')

          Rollbar.last_report[:person]
        end

        context 'default' do
          it 'sends the current user data excluding personally identifiable information' do
            expect(person_data).to eq(:id => user.id,
                                      :email => nil,
                                      :username => nil)
          end
        end

        context 'without EU GDPR subjects' do
          context 'configured to send email addresses' do
            before { Rollbar.configure { |config| config.person_email_method = 'email' } }

            it 'sends the current user data including email address' do
              expect(person_data).to eq(:id => user.id,
                                        :email => 'foo@bar.com',
                                        :username => nil)
            end

            context 'configured to send email addresses and username' do
              before { Rollbar.configure { |config| config.person_username_method = 'username' } }

              it 'sends the current user data including email address and username' do
                expect(person_data).to eq(:id => user.id,
                                          :email => 'foo@bar.com',
                                          :username => 'the_username')
              end
            end
          end
        end

        context 'when ActiveRecord times out' do
          it 'succeeds with empty person object' do
            allow_any_instance_of(ActiveRecord::ConnectionAdapters::ConnectionPool)
              .to receive(:with_connection)
              .and_raise(ActiveRecord::ConnectionTimeoutError)

            expect(person_data).to eq({})
          end
        end
      end
    end
  end

  context 'with routing errors', :type => :request do
    it 'raises a RoutingError exception' do
      expect { get '/foo/bar', *wrap_process_args(:foo => :bar) }.to raise_exception(ActionController::RoutingError)

      report = Rollbar.last_report
      expect(report[:request][:GET]['foo']).to be_eql('bar')
    end
  end

  context 'with ip parsing raising error' do
    it 'raise a IpSpoofAttackError exception' do
      controller.request.env['action_dispatch.remote_ip'] = GetIpRaising.new

      expect do
        expect(controller.send(:rollbar_request_data)[:user_ip]).to be_nil
      end.not_to raise_exception
    end
  end

  context 'with file uploads', :type => 'request' do
    let(:file1) { fixture_file_upload('spec/fixtures/file1') }
    let(:file2) { fixture_file_upload('spec/fixtures/file2') }

    context 'with a single upload' do
      it 'saves attachment data' do
        expect { post '/file_upload', *wrap_process_args(:upload => file1) }.to raise_exception(NameError)

        upload_param = Rollbar.last_report[:request][:POST]['upload']

        expect(upload_param).to have_key(:filename)
        expect(upload_param).to have_key(:type)
        expect(upload_param).to have_key(:name)
        expect(upload_param).to have_key(:head)

        expect(upload_param[:tempfile]).to be_eql("Skipped value of class 'Tempfile'")
      end
    end

    context 'with multiple uploads', :type => :request do
      it 'saves attachment data for all uploads' do
        expect { post '/file_upload', *wrap_process_args(:upload => [file1, file2]) }.to raise_exception(NameError)
        sent_params = Rollbar.last_report[:request][:POST]['upload']

        expect(sent_params).to be_kind_of(Array)
        expect(sent_params.size).to be(2)
      end
    end
  end

  context 'with session data', :type => :request do
    before { get '/set_session_data' }

    it 'reports the session data' do
      expect { get '/use_session_data' }.to raise_exception(NoMethodError)

      session_data = Rollbar.last_report[:request][:session]

      expect(session_data['some_value']).to be_eql('this-is-a-cool-value')
    end

    it 'scrubs session id by default from the request' do
      expect { get '/use_session_data' }.to raise_exception(NoMethodError)

      expect(Rollbar.last_report[:request][:session]['session_id']).to match('\*{3,8}')
    end
  end

  context 'with json ACCEPT header', :type => 'request' do
    let(:params) { { :foo => :bar } }

    it 'parses the correct headers' do
      expect do
        post '/cause_exception', *wrap_process_args(params, 'ACCEPT' => 'application/vnd.github.v3+json')
      end.to raise_exception(NameError)

      expect(Rollbar.last_report[:request][:POST]['foo']).to be_eql('bar')
    end
  end

  context 'with params to be scrubed from URL', :type => :request do
    before do
      Rollbar.configure do |config|
        config.scrub_fields = [:password]
      end
    end

    let(:headers) do
      {
        'ORIGINAL_FULLPATH' => '/cause_exception?password=my-secret-password'
      }
    end

    it 'scrubs sensible data from URL' do
      expect { get '/cause_exception', *wrap_process_args({ :password => 'my-secret-password' }, headers) }.to raise_exception(NameError)

      request_data = Rollbar.last_report[:request]

      expect(request_data[:url]).to match('http:\/\/www.example.com\/cause_exception\?password=\*{3,8}')
    end
  end

  after do
    Rollbar.configure do |config|
      config.logger = ::Rails.logger
    end
  end
end
