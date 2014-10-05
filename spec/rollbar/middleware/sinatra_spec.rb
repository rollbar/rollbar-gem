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
end

describe Rollbar::Middleware::Sinatra do
  include Rack::Test::Methods

  def app
    SinatraDummy
  end

  let(:expected_report_args) do
    [exception, kind_of(Hash), kind_of(Hash)]
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
          expect(Rollbar).to receive(:report_exception).with(*expected_report_args)

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
          expect(Rollbar).to receive(:report_exception).with(*expected_report_args)
          get '/foo'
        end
      end
    end

    context 'for a NOT crashing endpoint' do
      it 'doesnt report any error to Rollbar API' do
        expect(Rollbar).not_to receive(:report_exception)
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
        expect(Rollbar).to receive(:report_exception).with(*expected_report_args)

        expect do
          get '/foo'
        end.to raise_error(exception)
      end
    end
  end
end
