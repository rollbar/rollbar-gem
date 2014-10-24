require 'spec_helper'
require 'rack'
require 'rack/builder'
require 'rack/mock'
require 'rollbar/middleware/rack/builder'


describe Rollbar::Middleware::Rack::Builder do
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

    context 'with an single element array params in POST' do
      before do
        Rollbar.configure do |config|
          config.scrub_fields = [:secret]
        end
      end

      let(:params) do
        [{ :secret => 'hidden', :willsee => 'visible'}]
      end

      it 'scrub custom fields in array params' do
        expect do
          request.post('/will_crash', :input => params.to_json, 'CONTENT_TYPE' => 'application/json')
        end.to raise_error(exception)

        filtered = Rollbar.last_report[:request][:params]

        expect(filtered['secret']).to be_eql('******')
        expect(filtered['willsee']).to be_eql('visible')
      end
    end

    context 'with an two element array params in POST' do
      let(:params) do
        [{ :secret => 'hidden', :willsee => 'visible'},
         { :foo => 'bar', :key => 'value'}]
      end

      it 'doesnt merge the post params in the reported params' do
        expect do
          request.post('/will_crash', :input => params.to_json, 'CONTENT_TYPE' => 'application/json')
        end.to raise_error(exception)

        reported_params = Rollbar.last_report[:request][:params]
        expect(reported_params).to be_eql({})
      end
    end
  end
end
