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
end
