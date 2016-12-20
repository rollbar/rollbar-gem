require 'spec_helper'
require 'rack'
require 'rack/builder'
require 'rack/mock'
require 'rollbar'

Rollbar.plugins.load!

describe Rollbar::Middleware::Rack::Builder, :reconfigure_notifier => true do
  class RackMockError < Exception; end

  let(:action) do
    proc { fail(RackMockError, 'the-error') }
  end

  let(:app) do
    action_proc = action

    ::Rack::Builder.new { run action_proc }
  end

  let(:request) do
    ::Rack::MockRequest.new(app)
  end

  let(:exception) { kind_of(RackMockError) }
  let(:uncaught_level) { Rollbar.configuration.uncaught_exception_level }

  it 'reports the error to Rollbar' do
    expect(Rollbar).to receive(:log).with(uncaught_level, exception, :use_exception_level_filters => true)
    expect { request.get('/will_crash') }.to raise_error(exception)
  end

  context 'with GET parameters' do
    let(:params) do
      { 'key' => 'value' }
    end

    it 'sends them to Rollbar' do
      expect do
        request.get('/will_crash', :params => params)
      end.to raise_error(exception)

      expect(Rollbar.last_report[:request][:GET]).to be_eql(params)
    end
  end

  context 'with JSON body parameters' do
    let(:params) do
      { 'key' => 'value' }
    end

    it 'sends them to Rollbar' do
      expect do
        request.post('/will_crash', :input => params.to_json, 'CONTENT_TYPE' => 'application/json')
      end.to raise_error(exception)

      expect(Rollbar.last_report[:request][:body]).to be_eql(params.to_json)
    end
  end

  context 'with array POST parameters' do
    let(:params) do
      [{ :key => 'value'}, 'string', 10]
    end

    it 'sends a body.multi key in params' do
      expect do
        request.post('/will_crash', :input => params.to_json, 'CONTENT_TYPE' => 'application/json')
      end.to raise_error(exception)

      reported_body = Rollbar.last_report[:request][:body]
      expect(reported_body).to be_eql({ 'body.multi' => [{'key' => 'value'}, 'string', 10] }.to_json)
    end
  end

  context 'with not array or hash POST parameters' do
    let(:params) { 1000 }

    it 'sends a body.multi key in params' do
      expect do
        request.post('/will_crash', :input => params.to_json, 'CONTENT_TYPE' => 'application/json')
      end.to raise_error(exception)

      reported_body = Rollbar.last_report[:request][:body]
      expect(reported_body).to be_eql({ 'body.value' => params }.to_json)
    end
  end

  context 'with multiple HTTP_X_FORWARDED_PROTO values' do
    let(:headers) do
      { 'HTTP_X_FORWARDED_PROTO' => 'https,http' }
    end

    it 'uses the first scheme to generate the url' do
      expect do
        request.post('/will_crash', headers)
      end.to raise_error(exception)

      last_report = Rollbar.last_report
      expect(last_report[:request][:url]).to match(/https:/)
    end
  end

  context 'without HTTP_X_FORWARDED_PROTO' do
    it 'uses the the url_scheme set by Rack' do
      expect do
        request.post('/will_crash')
      end.to raise_error(exception)

      last_report = Rollbar.last_report
      expect(last_report[:request][:url]).to match(/http:/)
    end
  end

  context 'with single HTTP_X_FORWARDED_PROTO value' do
    let(:headers) do
      { 'HTTP_X_FORWARDED_PROTO' => 'https' }
    end

    it 'uses the scheme received in X-Forwarded-Proto header' do
      expect do
        request.post('/will_crash', headers)
      end.to raise_error(exception)

      last_report = Rollbar.last_report
      expect(last_report[:request][:url]).to match(/https:/)
    end
  end

  context 'with person data' do
    let(:person_data) do
      { 'email' => 'person@example.com' }
    end

    it 'includes person data from env' do
      expect do
        request.get('/will_crash', 'rollbar.person_data' => person_data)
      end.to raise_error(exception)

      expect(Rollbar.last_report[:person]).to be_eql(person_data)
    end

    it 'includes empty person data when not in env' do
      expect do
        request.get('/will_crash')
      end.to raise_error(exception)

      expect(Rollbar.last_report[:person]).to be_eql({})
    end
  end
end
