require 'spec_helper'
require 'rollbar/middleware/sinatra'
require 'sinatra/base'
require 'rack/test'

class SinatraDummy < Sinatra::Base
  class DummyError < StandardError; end

  use Rollbar::Middleware::Sinatra

  get '/foo' do
    raise DummyError.new
  end

  get '/bar' do
    'this will not crash'
  end

  post '/crash_post' do
    raise DummyError.new
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
    [uncaught_level, exception]
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

        expect(Rollbar.last_report[:request][:params]).to be_eql(params)
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

        expect(Rollbar.last_report[:request][:params]).to be_eql(params)
      end
    end

    context 'with JSON POST parameters' do
      let(:exception) { kind_of(SinatraDummy::DummyError) }
      let(:params) do
        {
          'key' => 'value'
        }
      end

      it 'appear in the sent payload' do
        expect do
          post '/crash_post', params.to_json, { 'CONTENT_TYPE' => 'application/json' }
        end.to raise_error(exception)

        expect(Rollbar.last_report[:request][:params]).to be_eql(params)
      end
    end

    it 'resets the notifier in every request' do
      get '/bar'
      id1 = Rollbar.notifier.object_id

      get '/bar'
      id2 = Rollbar.notifier.object_id

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
  end
end
