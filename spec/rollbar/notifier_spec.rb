require 'rollbar'
require 'rollbar/notifier'

describe Rollbar::Notifier do
  describe '#with_config' do
    let(:new_config) do
      { 'environment' => 'foo' }
    end

    it 'uses the new config and restores the old one' do
      config1 = subject.configuration

      subject.with_config(:environment => 'bar') do
        expect(subject.configuration).not_to be(config1)
      end

      expect(subject.configuration).to be(config1)
    end
  end
end
