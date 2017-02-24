require 'spec_helper'
require 'tempfile'
require 'rollbar/scrubbers/params'

require 'rspec/expectations'

describe Rollbar::Scrubbers::Params do
  describe '.call' do
    it 'calls #call in a new instance' do
      arguments = [:foo, :bar]
      expect_any_instance_of(described_class).to receive(:call).with(*arguments)

      described_class.call(*arguments)
    end
  end

  describe '#call' do
    let(:options) do
      {
        :params => params,
        :config => scrub_config
      }
    end

    context 'with scrub fields configured' do
      let(:scrub_config) do
        [:secret, :password]
      end

      context 'with Array object' do
        let(:params) do
          [
            {
              :foo => 'bar',
              :secret => 'the-secret',
              :password => 'the-password',
              :password_confirmation => 'the-password'
            }
          ]
        end
        let(:result) do
          [
            {
              :foo => 'bar',
              :secret => /\*+/,
              :password => /\*+/,
              :password_confirmation => /\*+/
            }
          ]
        end

        it 'scrubs the required parameters' do
          expect(subject.call(options).first).to be_eql_hash_with_regexes(result.first)
        end
      end

      context 'with simple Hash' do
        let(:params) do
          {
            :foo => 'bar',
            :secret => 'the-secret',
            :password => 'the-password',
            :password_confirmation => 'the-password'
          }
        end
        let(:result) do
          {
            :foo => 'bar',
            :secret => /\*+/,
            :password => /\*+/,
            :password_confirmation => /\*+/
          }
        end

        it 'scrubs the required parameters' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end
      end

      context 'with nested Hash' do
        let(:params) do
          {
            :foo => 'bar',
            :extra => {
              :secret => 'the-secret',
              :password => 'the-password',
              :password_confirmation => 'the-password'
            }
          }
        end
        let(:result) do
          {
            :foo => 'bar',
            :extra => {
              :secret => /\*+/,
              :password => /\*+/,
              :password_confirmation => /\*+/
            }
          }
        end

        it 'scrubs the required parameters' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end
      end

      context 'with nested Array' do
        let(:params) do
          {
            :foo => 'bar',
            :extra => [{
              :secret => 'the-secret',
              :password => 'the-password',
              :password_confirmation => 'the-password'
            }]
          }
        end
        let(:result) do
          {
            :foo => 'bar',
            :extra => [{
              :secret => /\*+/,
              :password => /\*+/,
              :password_confirmation => /\*+/
            }]
          }
        end

        it 'scrubs the required parameters' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end
      end

      context 'with skipped instance' do
        let(:tempfile) { Tempfile.new('foo') }
        let(:params) do
          {
            :foo => 'bar',
            :extra => [{
              :secret => 'the-secret',
              :password => 'the-password',
              :password_confirmation => 'the-password',
              :skipped => tempfile
            }]
          }
        end
        let(:result) do
          {
            :foo => 'bar',
            :extra => [{
              :secret => /\*+/,
              :password => /\*+/,
              :password_confirmation => /\*+/,
              :skipped => "Skipped value of class 'Tempfile'"
            }]
          }
        end

        after { tempfile.close }

        it 'scrubs the required parameters' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end
      end

      context 'with attachment instance' do
        let(:tempfile) { double(:size => 100) }
        let(:attachment) do
          double(:class => double(:name => 'ActionDispatch::Http::UploadedFile'),
                 :tempfile => tempfile,
                 :content_type => 'content-type',
                 'original_filename' => 'filename')
        end
        let(:params) do
          {
            :foo => 'bar',
            :extra => [{
              :secret => 'the-secret',
              :password => 'the-password',
              :password_confirmation => 'the-password',
              :attachment => attachment
            }]
          }
        end
        let(:result) do
          {
            :foo => 'bar',
            :extra => [{
              :secret => /\*+/,
              :password => /\*+/,
              :password_confirmation => /\*+/,
              :attachment => {
                :content_type => 'content-type',
                :original_filename => 'filename',
                :size => 100
              }
            }]
          }
        end

        it 'scrubs the required parameters' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end

        context 'if getting the attachment values fails' do
          let(:tempfile) { Object.new }
          let(:attachment) do
            double(:class => double(:name => 'ActionDispatch::Http::UploadedFile'),
                   :tempfile => tempfile,
                   :content_type => 'content-type',
                   'original_filename' => 'filename')
          end
          let(:params) do
            {
              :foo => 'bar',
              :extra => [{
                :secret => 'the-secret',
                :password => 'the-password',
                :password_confirmation => 'the-password',
                :attachment => attachment
              }]
            }
          end
          let(:result) do
            {
              :foo => 'bar',
              :extra => [{
                :secret => /\*+/,
                :password => /\*+/,
                :password_confirmation => /\*+/,
                :attachment => 'Uploaded file'
              }]
            }
          end

          it 'scrubs the required parameters' do
            expect(subject.call(options)).to be_eql_hash_with_regexes(result)
          end
        end
      end

      context 'without params' do
        let(:params) do
          nil
        end
        let(:result) do
          {}
        end

        it 'scrubs the required parameters' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end
      end
    end

    context 'with :scrub_all option' do
      let(:scrub_config) { :scrub_all }
      let(:params) do
        {
          :foo => 'bar',
          :password => 'the-password',
          :bar => 'foo',
          :extra => {
            :foo => 'more-foo',
            :bar => 'more-bar'
          }
        }
      end
      let(:result) do
        {
          :foo => /\*+/,
          :password => /\*+/,
          :bar => /\*+/,
          :extra => /\*+/
        }
      end

      it 'scrubs the required parameters' do
        expect(subject.call(options)).to be_eql_hash_with_regexes(result)
      end
    end
  end
end

describe Rollbar::Scrubbers::Params::ATTACHMENT_CLASSES do
  it 'has the correct values' do
    expect(described_class).to be_eql(%w(ActionDispatch::Http::UploadedFile Rack::Multipart::UploadedFile).freeze)
  end
end

describe Rollbar::Scrubbers::Params::SKIPPED_CLASSES do
  it 'has the correct values' do
    expect(described_class).to be_eql([Tempfile])
  end
end

