require 'spec_helper'
require 'rollbar/middleware/sinatra'
require 'sinatra/base'
require 'rack/test'

class SinatraDummy < Sinatra::Base
  class DummyError < StandardError; end

  use Rollbar::Middleware::Sinatra

  get '/foo' do
    raise DummyError
  end

  get '/bar' do
    'this will not crash'
  end

  get '/cause_exception_with_locals' do
    cause_exception_with_locals
  end

  post '/crash_post' do
    raise DummyError
  end

  def cause_exception_with_locals
    foo = false

    (0..2).each do |index|
      foo = Post

      build_hash_with_locals(foo, index)
    end
  end

  def build_hash_with_locals(foo, _index)
    foo.tap do |obj|
      bar = 'bar'
      hash = { :foo => obj, :bar => bar }
      hash.invalid_method
    end
  end
end

describe Rollbar::Middleware::Sinatra, :reconfigure_notifier => true do
  include Rack::Test::Methods

  def app
    SinatraDummy
  end

  let(:logger_mock) { double('logger').as_null_object }

  before do
    Rollbar.configure do |config|
      config.logger = logger_mock
      config.framework = 'Sinatra'
    end
  end

  let(:uncaught_level) do
    Rollbar.configuration.uncaught_exception_level
  end

  let(:expected_report_args) do
    [uncaught_level, exception, { :use_exception_level_filters => true }]
  end

  describe '#call' do
    context 'for a crashing endpoint' do
      # this is the default for test mode in Sinatra
      context 'with raise_errors? == true' do
        let(:exception) { kind_of(SinatraDummy::DummyError) }

        before do
          allow(app.settings).to receive(:raise_errors?).and_return(true)
        end

        it 'reports the error to Rollbar API and raises error' do
          expect(Rollbar).to receive(:log).with(*expected_report_args)

          expect do
            get '/foo'
          end.to raise_error(SinatraDummy::DummyError)
        end

        context 'with capture_uncaught == false' do
          before do
            Rollbar.configure do |config|
              config.capture_uncaught = false
            end
          end

          it 'should not report the exception' do
            expect(Rollbar).to_not receive(:log)

            expect { get '/foo' }.to raise_error(SinatraDummy::DummyError)
          end
        end
      end

      context 'with raise_errors? == false' do
        let(:exception) { kind_of(SinatraDummy::DummyError) }

        before do
          allow(app.settings).to receive(:raise_errors?).and_return(false)
        end

        it 'reports the error to Rollbar, but nothing is raised' do
          expect(Rollbar).to receive(:log).with(*expected_report_args)
          get '/foo'
        end
      end
    end

    context 'for a NOT crashing endpoint' do
      it 'doesnt report any error to Rollbar API' do
        expect(Rollbar).not_to receive(:log)
        get '/bar'
      end
    end

    context 'if the middleware itself fails' do
      let(:exception) { Exception.new }

      before do
        allow_any_instance_of(described_class).to receive(:framework_error).and_raise(exception)
        allow(app.settings).to receive(:raise_errors?).and_return(false)
      end

      it 'reports the report error' do
        expect(Rollbar).to receive(:log).with(*expected_report_args)

        expect do
          get '/foo'
        end.to raise_error(exception)
      end
    end

    context 'with GET parameters' do
      let(:exception) { kind_of(SinatraDummy::DummyError) }
      let(:params) do
        {
          'key' => 'value'
        }
      end

      it 'appear in the sent payload' do
        expect do
          get '/foo', params
        end.to raise_error(exception)

        expect(Rollbar.last_report[:request][:GET]).to be_eql(params)
      end
    end

    context 'with POST parameters' do
      let(:exception) { kind_of(SinatraDummy::DummyError) }
      let(:params) do
        {
          'key' => 'value'
        }
      end

      it 'appear in the sent payload' do
        expect do
          post '/crash_post', params
        end.to raise_error(exception)

        expect(Rollbar.last_report[:request][:POST]).to be_eql(params)
      end
    end

    context 'with JSON POST parameters' do
      let(:exception) { kind_of(SinatraDummy::DummyError) }
      let(:params) do
        {
          'key' => 'value'
        }
      end

      it 'appears in the sent payload when application/json is the content type' do
        expect do
          post '/crash_post', params.to_json, 'CONTENT_TYPE' => 'application/json'
        end.to raise_error(exception)

        expect(Rollbar.last_report[:request][:body]).to be_eql(params.to_json)
      end

      it 'appears in the sent payload when the accepts header contains json' do
        expect do
          post '/crash_post', params, 'ACCEPT' => 'application/vnd.github.v3+json'
        end.to raise_error(exception)

        expect(Rollbar.last_report[:request][:POST]).to be_eql(params)
      end
    end

    it 'resets the notifier scope in every request' do
      get '/bar'
      id1 = Rollbar.scope_object.object_id

      get '/bar'
      id2 = Rollbar.scope_object.object_id

      expect(id1).not_to be_eql(id2)
    end

    context 'with person data' do
      let(:exception) { kind_of(SinatraDummy::DummyError) }
      let(:person_data) do
        { 'email' => 'person@example.com' }
      end

      it 'includes person data from env' do
        expect do
          get '/foo', {}, 'rollbar.person_data' => person_data
        end.to raise_error(exception)

        expect(Rollbar.last_report[:person]).to be_eql(person_data)
      end

      it 'includes empty person data when not in env' do
        expect do
          get '/foo'
        end.to raise_error(exception)

        expect(Rollbar.last_report[:person]).to be_eql({})
      end
    end

    describe 'configuration.locals', :if => RUBY_VERSION >= '2.3.0' &&
                                            !(defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby') do
      context 'when locals is enabled' do
        before do
          Rollbar.configure do |config|
            config.send_extra_frame_data = :all
            config.locals = { :enabled => true }
          end
        end

        let(:locals) do
          [
            {
              :obj => 'Post',
              :bar => 'bar',
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
            config.send_extra_frame_data = :all
          end
        end

        it 'should not include locals in extra data' do
          logger_mock.should_receive(:info).with('[Rollbar] Success').once

          expect { get '/cause_exception_with_locals' }.to raise_exception(NoMethodError)
          expect(Rollbar.last_report[:body][:trace][:frames][-1][:locals]).to be_eql({})
        end
      end
    end
  end
end
