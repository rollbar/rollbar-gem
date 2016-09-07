require 'rollbar'
require 'rollbar/notifier'

describe Rollbar::Notifier do
  describe '#scope' do
    let(:new_scope) do
      { 'foo' => 'bar' }
    end
    let(:new_config) do
      { 'environment' => 'foo' }
    end

    it 'creates a new notifier with merged scope and configuration' do
      new_notifier = subject.scope(new_scope, new_config)

      expect(new_notifier).not_to be(subject)
      expect(new_notifier.configuration.environment).to be_eql('foo')
      expect(new_notifier.scope_object['foo']).to be_eql('bar')
      expect(new_notifier.configuration).not_to be(subject.configuration)
      expect(new_notifier.scope_object).not_to be(subject.scope_object)
    end
  end

  describe '#scope!' do
    let(:new_scope) do
      { 'foo' => 'bar' }
    end
    let(:new_config) do
      { 'environment' => 'foo' }
    end

    it 'mutates the notifier with a merged scope and configuration' do
      new_notifier = subject.scope!(new_scope, new_config)

      expect(new_notifier).to be(subject)
      expect(new_notifier.configuration.environment).to be_eql('foo')
      expect(new_notifier.scope_object['foo']).to be_eql('bar')
      expect(new_notifier.configuration).to be(subject.configuration)
      expect(new_notifier.scope_object).to be(subject.scope_object)
    end
  end
end
