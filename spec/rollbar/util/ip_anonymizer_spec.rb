require 'spec_helper'
require 'rollbar/util/ip_anonymizer'

describe Rollbar::Util::IPAnonymizer do
  before do
    Rollbar.configuration.anonymize_user_ip = true
  end

  context 'with IPv4 address' do
    let(:ip) { '127.0.0.1' }

    it 'anonymizes the IP by replacing the last octet with 0' do
      anonymized_ip = described_class.anonymize_ip(ip)

      expect(anonymized_ip).to be_eql(IPAddr.new('127.0.0.0').to_s)
    end
  end

  context 'with IPv6 address' do
    let(:ip) { '2001:0db8:85a3:0000:0000:8a2e:0370:7334' }

    it 'anonymizes the IP by replacing the last 80 bits with 0' do
      anonymized_ip = described_class.anonymize_ip(ip)

      expect(anonymized_ip).to be_eql(IPAddr.new('2001:db8:85a3::').to_s)
    end
  end
end
