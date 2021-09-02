require 'spec_helper'
require 'rollbar/middleware/rack'
require 'rack/test'

describe Rollbar::Middleware::Rack, :reconfigure_notifier => true do
  include Rack::Test::Methods

  class RackMockError < RuntimeError; end

  let(:logger_mock) { double('logger').as_null_object }

  before do
    Rollbar.configure do |config|
      config.logger = logger_mock
      config.framework = 'Rack'
    end
  end

  let(:uncaught_level) do
    Rollbar.configuration.uncaught_exception_level
  end

  let(:expected_report_args) do
    [uncaught_level, exception, { :use_exception_level_filters => true }]
  end

  describe '#call' do
    context 'for a framework reported error' do
      let(:exception) { kind_of(RackMockError) }
      let(:env) { Rack::MockRequest.env_for('/', 'rack.exception' => exception) }
      let(:mock_app) { MockApp.new }
      let(:middleware) { described_class.new(mock_app) }

      it 'reports the error' do
        expect(Rollbar).to receive(:log).with(*expected_report_args)

        middleware.call(env)
      end
    end
  end
end
