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
    it 'returns a Hash object' do
      expect_any_instance_of(Rollbar::Scrubbers::URL).to receive(:call).with(kind_of(String))
      expect(subject.extract_request_data_from_rack(env)).to be_kind_of(Hash)
    end
  end
end
