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
        :scrub_password => Rollbar.configuration.scrub_password
      }
      expect(Rollbar::Scrubbers::URL).to receive(:new).with(scrubber_config).and_return(scrubber)
      expect(scrubber).to receive(:call).with(kind_of(String))

      result = subject.extract_request_data_from_rack(env)

      expect(result).to be_kind_of(Hash)
    end
  end
end
