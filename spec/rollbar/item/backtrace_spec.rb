require 'spec_helper'
require 'tempfile'
require 'rollbar/item/backtrace'

describe Rollbar::Item::Backtrace do
  describe '#get_file_lines' do
    subject { described_class.new(exception) }

    let(:exception) { Exception.new }
    let(:file) { Tempfile.new('foo') }

    before do
      File.open(file.path, 'w') do |f|
        f << "foo\nbar"
      end
    end

    it 'returns the lines of the file' do
      lines = subject.get_file_lines(file.path)

      expect(lines.size).to be_eql(2)
      expect(lines[0]).to be_eql('foo')
      expect(lines[1]).to be_eql('bar')
    end
  end

  describe '#map_frames' do
    context 'when using backtrace_cleaner',
            :if => Gem.loaded_specs['activesupport'].version >= Gem::Version.new('3.0') do
      subject { described_class.new(exception, { :configuration => config }) }

      let(:config) do
        config = Rollbar::Configuration.new
        config.backtrace_cleaner = backtrace_cleaner
        config
      end

      let(:backtrace_cleaner) do
        bc = ActiveSupport::BacktraceCleaner.new
        bc.add_silencer { |line| line =~ /gems/ }
        bc
      end

      let(:exception) do
        begin
          raise 'Test'
        rescue StandardError => e
          e
        end
      end

      it 'filters the backtrace' do
        original_length = exception.backtrace.length
        backtrace = subject.send(:map_frames, exception)
        expect(backtrace.length).to be < original_length
      end
    end

    context 'when not using backtrace_cleaner' do
      subject { described_class.new(exception, { :configuration => config }) }

      let(:config) do
        Rollbar::Configuration.new
      end

      let(:exception) do
        begin
          raise 'Test'
        rescue StandardError => e
          e
        end
      end

      it "doesn't filter the backtrace" do
        original_length = exception.backtrace.length
        backtrace = subject.send(:map_frames, exception)
        expect(backtrace.length).to be_eql(original_length)
      end
    end
  end
end
