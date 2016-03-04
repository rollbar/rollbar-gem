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

  describe '#extract_request_data_from_rack' do
    let(:scrubber) { double }

    it 'returns a Hash object' do
      scrubber_config = {
        :scrub_fields => kind_of(Array),
        :scrub_user => Rollbar.configuration.scrub_user,
        :scrub_password => Rollbar.configuration.scrub_password,
        :randomize_scrub_length => Rollbar.configuration.randomize_scrub_length
      }
      expect(Rollbar::Scrubbers::URL).to receive(:new).with(scrubber_config).and_return(scrubber)
      expect(scrubber).to receive(:call).with(kind_of(String))

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
    end
  end

  describe '#rollbar_scrubbed_value' do
    context 'with random scrub length' do
      before do
        allow(Rollbar.configuration).to receive(:randomize_scrub_length).and_return(true)
      end

      let(:value) { 'herecomesaverylongvalue' }

      it 'randomizes the scrubbed string' do
        expect(subject.rollbar_scrubbed(value)).to match(/\*{3,8}/)
      end
    end

    context 'with no-random scrub length' do
      before do
        allow(Rollbar.configuration).to receive(:randomize_scrub_length).and_return(false)
      end

      let(:value) { 'herecomesaverylongvalue' }

      it 'randomizes the scrubbed string' do
        expect(subject.rollbar_scrubbed(value)).to match(/\*{#{value.length}}/)
      end
    end
  end
end
