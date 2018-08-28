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
      expect(subject.configuration.environment).to be_eql(nil)
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
      result = subject.scope!(new_scope, new_config)

      expect(result).to be(subject)
      expect(subject.configuration.environment).to be_eql('foo')
      expect(subject.scope_object['foo']).to be_eql('bar')
      expect(subject.configuration).to be(subject.configuration)
      expect(subject.scope_object).to be(subject.scope_object)
    end
  end
  
  if RUBY_PLATFORM == 'java'
    describe '#extract_arguments' do
      # See https://docs.oracle.com/javase/8/docs/api/java/lang/Throwable.html
      # for more background
      it 'extracts java.lang.Exception' do
        begin
          raise java.lang.Exception.new('Hello')
        rescue => e
          message, exception, extra = Rollbar::Notifier.new.send(:extract_arguments, [e])
          expect(exception).to eq(e)
        end
      end
      
      it 'extracts java.lang.Error' do
        begin
          raise java.lang.AssertionError.new('Hello')
        rescue java.lang.Error => e
          message, exception, extra = Rollbar::Notifier.new.send(:extract_arguments, [e])
          expect(exception).to eq(e)
        end
      end
    end
  end
end
