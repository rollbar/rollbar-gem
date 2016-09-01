require 'spec_helper'
require 'rack/mock'

require 'rollbar/request_data_extractor'

class ExtractorDummy
  include Rollbar::RequestDataExtractor
end

describe Rollbar::RequestDataExtractor do
  subject { ExtractorDummy.new }

  let(:env) do
    Rack::MockRequest.env_for('/', 'HTTP_HOST' => 'localhost:81', 'HTTP_X_FORWARDED_HOST' => 'example.org:9292')
  end

  describe '#scrub_url' do
    let(:url) { 'http://this-is-the-url.com/foobar?param1=value1' }
    let(:sensitive_params) { [:param1, :param2] }
    let(:scrub_fields) { [:password, :secret] }

    before do
      allow(Rollbar.configuration).to receive(:scrub_fields).and_return(scrub_fields)
      allow(Rollbar.configuration).to receive(:scrub_user).and_return(true)
      allow(Rollbar.configuration).to receive(:scrub_password).and_return(true)
      allow(Rollbar.configuration).to receive(:randomize_secret_length).and_return(true)
    end

    it 'calls the scrubber with the correct options' do
      expected_options = {
        :url => url,
        :scrub_fields => [:password, :secret, :param1, :param2],
        :scrub_user => true,
        :scrub_password => true,
        :randomize_scrub_length => true
      }

      expect(Rollbar::Scrubbers::URL).to receive(:call).with(expected_options)

      subject.scrub_url(url, sensitive_params)
    end
  end

  describe '#scrub_params' do
    let(:params) do
      {
        :param1 => 'value1',
        :param2 => 'value2'
      }
    end
    let(:sensitive_params) { [:param1, :param2] }
    let(:scrub_fields) { [:password, :secret] }

    before do
      allow(Rollbar.configuration).to receive(:scrub_fields).and_return(scrub_fields)
    end

    it 'calls the scrubber with the correct options' do
      expected_options = {
        :params => params,
        :config => scrub_fields,
        :extra_fields => sensitive_params
      }

      expect(Rollbar::Scrubbers::Params).to receive(:call).with(expected_options)

      subject.scrub_params(params, sensitive_params)
    end
  end

  describe '#extract_request_data_from_rack' do
    it 'returns a Hash object' do
      expect(Rollbar::Scrubbers::URL).to receive(:call).with(kind_of(Hash)).and_call_original
      expect(Rollbar::Scrubbers::Params).to receive(:call).with(kind_of(Hash)).and_call_original.exactly(7)

      result = subject.extract_request_data_from_rack(env)

      expect(result).to be_kind_of(Hash)
    end

    context 'with invalid utf8 sequence in key', :if => RUBY_VERSION != '1.8.7'  do
      let(:data) do
        File.read(File.expand_path('../../support/encodings/iso_8859_9', __FILE__)).force_encoding(Encoding::ISO_8859_9)
      end
      let(:env) do
        env = Rack::MockRequest.env_for('/',
                                         'HTTP_HOST' => 'localhost:81',
                                         'HTTP_X_FORWARDED_HOST' => 'example.org:9292',
                                         'CONTENT_TYPE' => 'application/json')

        env['rack.session'] = { data => 'foo' }
        env
      end

      it 'doesnt crash' do
        result = subject.extract_request_data_from_rack(env)

        expect(result).to be_kind_of(Hash)
      end

      context 'with CONTENT_TYPE and CONTENT_LENGTH headers' do
        let(:env) do
          Rack::MockRequest.env_for('/',
                                    'HTTP_HOST' => 'localhost:81',
                                    'HTTP_X_FORWARDED_HOST' => 'example.org:9292',
                                    'CONTENT_TYPE' => 'application/json',
                                    'CONTENT_LENGTH' => 20)


        end

        it 'adds the content type header to the headers key' do
          result = subject.extract_request_data_from_rack(env)

          expect(result[:headers]['Content-Type']).to be_eql('application/json')
          expect(result[:headers]['Content-Length']).to be_eql(20)
        end
      end
    end
  end
end
