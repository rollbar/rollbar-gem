require 'spec_helper'
require 'rack'
require 'rack/builder'
require 'rack/mock'
require 'rollbar/middleware/rack/builder'


describe Rollbar::Middleware::Rack::Builder, reconfigure_notifier: true do
  class RackMockError < Exception; end

  let(:action) do
    proc { fail(RackMockError, 'the-error') }
  end

  let(:app) do
    action_proc = action

    Rack::Builder.new { run action_proc }
  end

  let(:request) do
    Rack::MockRequest.new(app)
  end

  let(:exception) { kind_of(RackMockError) }
  let(:uncaught_level) { Rollbar.configuration.uncaught_exception_level }

  it 'reports the error to Rollbar' do
    expect(Rollbar).to receive(:log).with(uncaught_level, exception)
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

      expect(Rollbar.last_report[:request][:params]).to be_eql(params)
    end
  end

  context 'with POST parameters' do
    let(:params) do
      { 'key' => 'value' }
    end

    it 'sends them to Rollbar' do
      expect do
        request.post('/will_crash', :input => params.to_json, 'CONTENT_TYPE' => 'application/json')
      end.to raise_error(exception)

      expect(Rollbar.last_report[:request][:params]).to be_eql(params)
    end

    context 'with crashing payload' do
      let(:body) { 'this is not a valid json' }

      it 'returns {} and doesnt raise' do
        expect do
          request.post('/dont_crash', :input => body, 'CONTENT_TYPE' => 'application/json')
        end.to raise_error(exception)

        expect(Rollbar.last_report[:request][:params]).to be_eql({})
      end
    end
  end
end
