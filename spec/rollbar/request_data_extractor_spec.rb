require 'spec_helper'
require 'rack/mock'

require 'rollbar/request_data_extractor'

class ExtractorDummy
  include Rollbar::RequestDataExtractor
end

describe Rollbar::RequestDataExtractor do
  subject { ExtractorDummy.new }

  let(:env) do
    Rack::MockRequest.env_for('/', 'HTTP_HOST' => 'localhost:81',
                                   'HTTP_X_FORWARDED_HOST' => 'example.org:9292')
  end

  describe '#scrub_url' do
    let(:url) { 'http://this-is-the-url.com/foobar?param1=value1' }
    let(:sensitive_params) { [:param1, :param2] }
    let(:scrub_fields) { [:password, :secret] }
    let(:scrub_whitelist) { false }

    before do
      allow(Rollbar.configuration).to receive(:scrub_fields).and_return(scrub_fields)
      allow(Rollbar.configuration).to receive(:scrub_user).and_return(true)
      allow(Rollbar.configuration).to receive(:scrub_password).and_return(true)
      allow(Rollbar.configuration).to receive(:randomize_secret_length).and_return(true)
      allow(Rollbar.configuration).to receive(:scrub_whitelist).and_return(false)
    end

    it 'calls the scrubber with the correct options' do
      expected_options = {
        :url => url,
        :scrub_fields => [:password, :secret, :param1, :param2],
        :scrub_user => true,
        :scrub_password => true,
        :randomize_scrub_length => false,
        :whitelist => false
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
    let(:scrub_whitelist) { false }

    before do
      allow(Rollbar.configuration).to receive(:scrub_fields)
        .and_return(scrub_fields)
      allow(Rollbar.configuration).to receive(:scrub_whitelist)
        .and_return(scrub_whitelist)
    end

    it 'calls the scrubber with the correct options' do
      expected_options = {
        :params => params,
        :config => scrub_fields,
        :extra_fields => sensitive_params,
        :whitelist => scrub_whitelist
      }

      expect(Rollbar::Scrubbers::Params).to receive(:call).with(expected_options)

      subject.scrub_params(params, sensitive_params)
    end
  end

  describe '#extract_request_data_from_rack' do
    it 'returns a Hash object' do
      expect(Rollbar::Scrubbers::URL).to receive(:call)
        .with(kind_of(Hash))
        .and_call_original
      expect(Rollbar::Scrubbers::Params).to receive(:call)
        .with(kind_of(Hash))
        .and_call_original.exactly(6)

      result = subject.extract_request_data_from_rack(env)

      expect(result).to be_kind_of(Hash)
    end

    context 'with scrub headers set' do
      let(:scrub_headers) do
        %w[HTTP_UPPER_CASE_HEADER http-lower-case-header Mixed-CASE-header]
      end

      let(:env) do
        Rack::MockRequest.env_for('/',
                                  'HTTP_UPPER_CASE_HEADER' => 'foo',
                                  'HTTP_LOWER_CASE_HEADER' => 'bar',
                                  'HTTP_MIXED_CASE_HEADER' => 'baz')
      end

      before do
        allow(Rollbar.configuration).to receive(:scrub_headers)
          .and_return(scrub_headers)
      end

      it 'returns scrubbed headers' do
        result = subject.extract_request_data_from_rack(env)
        headers = result[:headers]

        expect(headers['Upper-Case-Header']).to match(/^\*+$/)
        expect(headers['Lower-Case-Header']).to match(/^\*+$/)
        expect(headers['Mixed-Case-Header']).to match(/^\*+$/)
      end
    end

    context 'with invalid utf8 sequence in key' do
      let(:data) do
        File.read(File.expand_path('../../support/encodings/iso_8859_9',
                                   __FILE__)).force_encoding(Encoding::ISO_8859_9)
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

    context 'with multiple IP addresses in headers and in user ip' do
      let(:env) do
        Rack::MockRequest.env_for('/',
                                  'HTTP_HOST' => 'localhost:81',
                                  'HTTP_X_FORWARDED_FOR' => x_forwarded_for,
                                  'HTTP_X_REAL_IP' => x_real_ip,
                                  'HTTP_CF_CONNECTING_IP' => cf_connecting_ip,
                                  'REMOTE_ADDR' => '3.3.3.3',
                                  'CONTENT_TYPE' => 'application/json',
                                  'CONTENT_LENGTH' => 20)
      end
      let(:cf_connecting_ip) { '4.3.2.1' }

      context 'with public client IP' do
        let(:x_forwarded_for) { '2.2.2.2, 3.3.3.3' }
        let(:x_real_ip) { '2.2.2.2' }

        it 'extracts the correct user IP' do
          result = subject.extract_request_data_from_rack(env)

          expect(result[:user_ip]).to be_eql('2.2.2.2')
        end

        it 'extracts the correct X-Forwarded-For' do
          result = subject.extract_request_data_from_rack(env)

          expect(result[:headers]['X-Forwarded-For']).to be_eql('2.2.2.2, 3.3.3.3')
        end

        it 'extracts the correct X-Real-Ip' do
          result = subject.extract_request_data_from_rack(env)

          expect(result[:headers]['X-Real-Ip']).to be_eql('2.2.2.2')
        end

        context 'with config.user_ip_rack_env_key set' do
          before do
            Rollbar.configuration.user_ip_rack_env_key = 'HTTP_CF_CONNECTING_IP'
          end

          it 'extracts from the correct key' do
            result = subject.extract_request_data_from_rack(env)

            expect(result[:user_ip]).to be_eql(cf_connecting_ip)
          end
        end

        context 'with collect_user_ip configuration option disabled' do
          before do
            Rollbar.configuration.collect_user_ip = false
          end

          it 'does not extract user\'s IP' do
            result = subject.extract_request_data_from_rack(env)

            expect(result[:user_ip]).to be_nil
          end

          it 'does not extract user\'s IP on X-Forwarded-For header' do
            result = subject.extract_request_data_from_rack(env)

            expect(result[:headers]['X-Forwarded-For']).to be_nil
          end

          it 'does not extract user\'s IP on X-Real-Ip header' do
            result = subject.extract_request_data_from_rack(env)

            expect(result[:headers]['X-Real-Ip']).to be_nil
          end
        end

        context 'with anonymize_user_ip configuration option enabled' do
          before do
            Rollbar.configuration.anonymize_user_ip = true
          end

          it 'it anonymizes the IPv4 address' do
            result = subject.extract_request_data_from_rack(env)

            expect(result[:user_ip]).to be_eql('2.2.2.0')
          end

          it 'it anonymizes IP addresses in X-Forwarded-For' do
            result = subject.extract_request_data_from_rack(env)

            expect(result[:headers]['X-Forwarded-For']).to be_eql('2.2.2.0, 3.3.3.0')
          end

          it 'it anonymizes IP addresses in X-Real-Ip' do
            result = subject.extract_request_data_from_rack(env)

            expect(result[:headers]['X-Real-Ip']).to be_eql('2.2.2.0')
          end
        end
      end

      context 'with private first client IP' do
        let(:x_forwarded_for) { '192.168.1.1, 2.2.2.2, 3.3.3.3' }
        let(:x_real_ip) { '2.2.2.2' }

        it 'extracts the correct user IP' do
          result = subject.extract_request_data_from_rack(env)

          expect(result[:user_ip]).to be_eql('2.2.2.2')
        end

        it 'extracts the correct X-Forwarded-For' do
          result = subject.extract_request_data_from_rack(env)

          expect(result[:headers]['X-Forwarded-For'])
            .to be_eql('192.168.1.1, 2.2.2.2, 3.3.3.3')
        end

        it 'extracts the correct X-Real-Ip' do
          result = subject.extract_request_data_from_rack(env)

          expect(result[:headers]['X-Real-Ip']).to be_eql('2.2.2.2')
        end
      end
    end

    context 'with form POST body (non-json)' do
      let(:body) { 'foo=1&bar=2' }
      let(:env) do
        Rack::MockRequest.env_for('/?foo=bar',
                                  'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
                                  'HTTP_ACCEPT' => 'application/json',
                                  :input => body,
                                  :method => 'POST')
      end

      it 'skips extracting the body' do
        result = subject.extract_request_data_from_rack(env)
        expect(result[:body]).to be_eql('{}')
      end
    end

    context 'with JSON POST body' do
      let(:params) { { 'key' => 'value' } }
      let(:body) { params.to_json }
      let(:env) do
        Rack::MockRequest.env_for('/?foo=bar',
                                  'CONTENT_TYPE' => 'application/json',
                                  :input => body,
                                  :method => 'POST')
      end

      it 'extracts the correct body' do
        result = subject.extract_request_data_from_rack(env)
        expect(result[:body]).to be_eql(body)
      end

      it 'extracts the correct body for JSONAPI' do
        env['CONTENT_TYPE'] = 'application/vnd.api+json'
        result = subject.extract_request_data_from_rack(env)
        expect(result[:body]).to be_eql(body)
      end

      it 'extracts the correct body for any JSON compatible MIME type' do
        env['CONTENT_TYPE'] = 'application/ld+json'
        result = subject.extract_request_data_from_rack(env)
        expect(result[:body]).to be_eql(body)
      end
    end

    context 'with JSON DELETE body' do
      let(:params) { { 'key' => 'value' } }
      let(:body) { params.to_json }
      let(:env) do
        Rack::MockRequest.env_for('/?foo=bar',
                                  'CONTENT_TYPE' => 'application/json',
                                  :input => body,
                                  :method => 'DELETE')
      end

      it 'extracts the correct body' do
        result = subject.extract_request_data_from_rack(env)
        expect(result[:body]).to be_eql(body)
      end
    end

    context 'with JSON PUT body' do
      let(:params) { { 'key' => 'value' } }
      let(:body) { params.to_json }
      let(:env) do
        Rack::MockRequest.env_for('/?foo=bar',
                                  'CONTENT_TYPE' => 'application/json',
                                  :input => body,
                                  :method => 'PUT')
      end

      it 'extracts the correct body' do
        result = subject.extract_request_data_from_rack(env)
        expect(result[:body]).to be_eql(body)
      end
    end

    context 'with non-rewindable input' do
      let(:params) { { 'key' => 'value' } }
      let(:body) { params.to_json }
      let(:env) do
        Rack::MockRequest.env_for('/?foo=bar',
                                  'CONTENT_TYPE' => 'application/json',
                                  :method => 'POST')
      end

      # According to Rack 3.0 "The input stream must respond to gets, each, and read"
      # https://github.com/rack/rack/blob/3.0.0/SPEC.rdoc#the-input-stream-
      let(:non_rewindable_input) do
        Class.new do
          def initialize(body)
            @body = body
          end

          def gets
            @body
          end

          def read
            @body
          end

          def each
            yield(@body)
          end
        end
      end

      before do
        env['rack.input'] = non_rewindable_input.new(body)
      end

      it 'skips extracting the body' do
        result = subject.extract_request_data_from_rack(env)
        expect(result[:body]).to be_eql('{}')
      end
    end

    context 'with POST params' do
      let(:params) { { 'key' => 'value' } }
      let(:env) do
        Rack::MockRequest.env_for('/?foo=bar',
                                  :params => params,
                                  :method => 'POST')
      end

      it 'extracts the correct user IP' do
        result = subject.extract_request_data_from_rack(env)
        expect(result[:POST]).to be_eql(params)
      end
    end

    context 'with GET params' do
      let(:params) { { 'key' => 'value' } }
      let(:env) do
        Rack::MockRequest.env_for('/?foo=bar',
                                  :params => params,
                                  :method => 'GET')
      end

      it 'extracts the correct user IP' do
        result = subject.extract_request_data_from_rack(env)
        expect(result[:GET]).to be_eql(params)
      end
    end
  end
end
