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
        :scrub_fields_whitelist => [],
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
    let(:whitelist) { [] }

    before do
      allow(Rollbar.configuration).to receive(:scrub_fields).and_return(scrub_fields)
    end

    it 'calls the scrubber with the correct options' do
      expected_options = {
        :params => params,
        :config => scrub_fields,
        :whitelist => whitelist,
        :extra_fields => sensitive_params
      }

      expect(Rollbar::Scrubbers::Params).to receive(:call).with(expected_options)

      subject.scrub_params(params, sensitive_params)
    end
  end

  describe '#extract_request_data_from_rack' do
    it 'returns a Hash object' do
      expect(Rollbar::Scrubbers::URL).to receive(:call).with(kind_of(Hash)).and_call_original
      expect(Rollbar::Scrubbers::Params).to receive(:call).with(kind_of(Hash)).and_call_original.exactly(6)

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

    context 'with multiple IP addresses in headers and in user ip' do
      let(:env) do
        Rack::MockRequest.env_for('/',
                                  'HTTP_HOST' => 'localhost:81',
                                  'HTTP_X_FORWARDED_FOR' => x_forwarded_for,
                                  'HTTP_X_REAL_IP' => x_real_ip,
                                  'REMOTE_ADDR' => '3.3.3.3',
                                  'CONTENT_TYPE' => 'application/json',
                                  'CONTENT_LENGTH' => 20)


      end

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

          expect(result[:headers]['X-Forwarded-For']).to be_eql('192.168.1.1, 2.2.2.2, 3.3.3.3')
        end
        
        it 'extracts the correct X-Real-Ip' do
          result = subject.extract_request_data_from_rack(env)

          expect(result[:headers]['X-Real-Ip']).to be_eql('2.2.2.2')
        end
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

      it 'extracts the correct user IP' do
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

      it 'extracts the correct user IP' do
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

      it 'extracts the correct user IP' do
        result = subject.extract_request_data_from_rack(env)
        expect(result[:body]).to be_eql(body)
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
