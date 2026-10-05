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
      options = {
        :params => params,
        :config => scrub_config
      }

      options[:whitelist] = whitelist if defined? whitelist

      options
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
        let(:scrub_config) do
          super().push(:other)
        end

        let(:params) do
          {
            :foo => 'bar',
            :extra => {
              :secret => 'the-secret',
              :password => 'the-password',
              :password_confirmation => 'the-password'
            },
            :other => {
              :param => 'filtered'
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
            },
            :other => /\*+/
          }
        end

        it 'scrubs the required parameters' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end
      end

      context 'with nested Array' do
        let(:scrub_config) do
          super().push(:other)
        end

        let(:params) do
          {
            :foo => 'bar',
            :extra => [{
              :secret => 'the-secret',
              :password => 'the-password',
              :password_confirmation => 'the-password'
            }],
            :other => [{
              :param => 'filtered'
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
            }],
            :other => /\*+/
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

      context 'with Hash-like objects that are not Hash subclasses' do
        let(:hash_like_class) do
          Class.new do
            def initialize(hash)
              @hash = hash
            end

            def to_hash
              @hash
            end
          end
        end

        let(:params) do
          {
            :foo => 'bar',
            :body => hash_like_class.new(:user => 'the-user',
                                         :password => 'the-password'),
            :list => [hash_like_class.new(:secret => 'the-secret', :foo => 'bar')]
          }
        end
        let(:result) do
          {
            :foo => 'bar',
            :body => { :user => 'the-user', :password => /\*+/ },
            :list => [{ :secret => /\*+/, :foo => 'bar' }]
          }
        end

        it 'scrubs the nested parameters' do
          scrubbed = subject.call(options)

          expect(scrubbed[:body]).to be_eql_hash_with_regexes(result[:body])
          expect(scrubbed[:list].first).to be_eql_hash_with_regexes(result[:list].first)
        end
      end

      context 'with ActionController::Parameters' do
        let(:raw_params) do
          {
            'user' => 'the-user',
            'password' => 'the-password',
            'nested' => { 'secret' => 'the-secret' }
          }
        end
        let(:expected) do
          {
            'user' => 'the-user',
            'password' => /\*+/,
            'nested' => { 'secret' => /\*+/ }
          }
        end

        context 'when not permitted' do
          let(:params) { { :body => ActionController::Parameters.new(raw_params) } }

          it 'scrubs the nested parameters' do
            expect(subject.call(options)[:body]).to be_eql_hash_with_regexes(expected)
          end
        end

        context 'when permitted' do
          let(:params) do
            {
              :body => ActionController::Parameters.new(raw_params)
                                                   .permit(:user, :password,
                                                           :nested => [:secret])
            }
          end

          it 'scrubs the nested parameters' do
            expect(subject.call(options)[:body]).to be_eql_hash_with_regexes(expected)
          end
        end

        context 'when passed as the top-level params' do
          let(:params) { ActionController::Parameters.new(raw_params) }

          it 'scrubs the parameters' do
            expect(subject.call(options)).to be_eql_hash_with_regexes(expected)
          end
        end
      end

      context 'with Regexp extra fields' do
        let(:options) do
          {
            :params => params,
            :config => scrub_config,
            :extra_fields => extra_fields
          }
        end
        let(:params) do
          {
            :foo => 'bar',
            :api_token => 'the-token',
            :user_email => 'foo@bar.com',
            :CaseSensitive => 'value',
            :casesensitive => 'value'
          }
        end
        # Same shape as Rails' action_dispatch.parameter_filter when
        # config.precompile_filter_parameters is enabled (Rails 7.1+ default).
        let(:extra_fields) { [/(?i:token)|(?i:email)/, /\ACaseSensitive\z/, -> {}] }
        let(:result) do
          {
            :foo => 'bar',
            :api_token => /\*+/,
            :user_email => /\*+/,
            :CaseSensitive => /\*+/,
            :casesensitive => 'value'
          }
        end

        it 'scrubs the parameters matching the regexps' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end
      end
    end

    context 'with :scrub_all option' do
      let(:scrub_config) { :scrub_all }

      context 'with simple hash' do
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
            :extra => {
              :foo => /\*+/,
              :bar => /\*+/
            }
          }
        end

        it 'scrubs the required parameters' do
          expect(subject.call(options)).to be_eql_hash_with_regexes(result)
        end
      end

      context 'with nested arrays' do
        let(:params) do
          {
            :foo => 'bar',
            :password => 'the-password',
            :bar => 'foo',
            :extra => [
              'hello world',
              {
                :foo => 'more-foo',
                :bar => 'more-bar'
              }
            ]
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

      context 'and with :whitelist option' do
        let(:whitelist) { [:foo, :buzz] }

        context 'with simple hash' do
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
              :foo => 'bar',
              :password => /\*+/,
              :bar => /\*+/,
              :extra => {
                :foo => 'more-foo',
                :bar => /\*+/
              }
            }
          end

          it 'scrubs the required parameters' do
            expect(subject.call(options)).to be_eql_hash_with_regexes(result)
          end
        end

        context 'with nested arrays' do
          let(:params) do
            {
              :foo => 'bar',
              :password => 'the-password',
              :bar => 'foo',
              :extra => [
                'hello world',
                {
                  :foo => 'more-foo',
                  :bar => 'more-bar'
                }
              ],
              :buzz => [
                'fizzbuzz',
                {
                  :a => 42,
                  :foo => 'another-foo',
                  :b => 'this should be scrubbed'
                }
              ]
            }
          end
          let(:result) do
            {
              :foo => 'bar',
              :password => /\*+/,
              :bar => /\*+/,
              :extra => /\*+/,
              :buzz => [
                'fizzbuzz',
                {
                  :a => /\*+/,
                  :foo => 'another-foo',
                  :b => /\*+/
                }
              ]
            }
          end

          it 'scrubs the required parameters' do
            expect(subject.call(options)).to be_eql_hash_with_regexes(result)
          end
        end
      end
    end

    context 'with :whitelist option' do
      let(:scrub_config) do
        [:secret, :password]
      end

      shared_examples 'scrubs params in various datatypes' do |whitelist|
        let(:whitelist) { whitelist }

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
                :password => 'the-password',
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
              :password => 'the-password',
              :password_confirmation => /\*+/
            }
          end

          it 'scrubs the required parameters' do
            expect(subject.call(options)).to be_eql_hash_with_regexes(result)
          end
        end

        context 'with nested Hash' do
          let(:scrub_config) do
            super().push(:param)
          end

          let(:params) do
            {
              :foo => 'bar',
              :extra => {
                :secret => 'the-secret',
                :password => 'the-password',
                :password_confirmation => 'the-password'
              },
              :other => {
                :param => 'filtered',
                :to_scrub => 'to_scrub'
              }
            }
          end
          let(:result) do
            {
              :foo => 'bar',
              :extra => {
                :secret => /\*+/,
                :password => 'the-password',
                :password_confirmation => /\*+/
              },
              :other => {
                :param => /\*+/,
                :to_scrub => 'to_scrub'
              }
            }
          end

          it 'scrubs the required parameters' do
            expect(subject.call(options)).to be_eql_hash_with_regexes(result)
          end
        end

        context 'with nested Array' do
          let(:scrub_config) do
            super().push(:param)
          end

          let(:params) do
            {
              :foo => 'bar',
              :extra => [{
                :secret => 'the-secret',
                :password => 'the-password',
                :password_confirmation => 'the-password'
              }],
              :other => [{
                :param => 'filtered',
                :to_scrub => 'to_scrub'
              }]
            }
          end
          let(:result) do
            {
              :foo => 'bar',
              :extra => [{
                :secret => /\*+/,
                :password => 'the-password',
                :password_confirmation => /\*+/
              }],
              :other => [{
                :param => /\*+/,
                :to_scrub => 'to_scrub'
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
                :password => 'the-password',
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
      end

      context 'when symbol whitelist' do
        include_examples 'scrubs params in various datatypes', [:password]
      end

      context 'when string whitelist' do
        include_examples 'scrubs params in various datatypes', ['password']
      end

      context 'when regex whitelist' do
        include_examples 'scrubs params in various datatypes', [/\Apass.*word\z/]
      end
    end

    # https://github.com/rollbar/rollbar-gem/issues/997
    context 'with the same object referenced more than once' do
      let(:scrub_config) { [:password] }
      let(:reference) { { :key => 'value', :password => 'the-password' } }
      let(:list) { [reference] }
      let(:params) do
        { :key1 => reference, :key2 => reference, :list1 => list, :list2 => list }
      end

      it 'returns scrubbed copies, never the original objects' do
        result = subject.call(options)

        [result[:key1], result[:key2], result[:list1][0], result[:list2][0]].each do |h|
          expect(h).not_to be(reference)
          expect(h[:key]).to eq('value')
          expect(h[:password]).to match(/\*+/)
        end
        expect(result[:list2]).not_to be(list)
        expect(reference[:password]).to eq('the-password')
      end
    end

    context 'with a circular reference' do
      let(:scrub_config) { [:password] }
      let(:params) do
        a = { :password => 'the-password' }
        a[:self] = a
        a
      end

      it 'does not leak the original object into the result' do
        result = subject.call(options)

        expect(result[:self]).to be(result)
        expect(result[:self]).not_to be(params)
        expect(result[:password]).to match(/\*+/)
      end
    end

    context 'with a Hash inside a nested Array' do
      let(:scrub_config) { [:password] }
      let(:params) { { :list => [[{ :password => 'the-password' }]] } }

      it 'copies and scrubs it' do
        result = subject.call(options)

        expect(result[:list][0]).not_to be(params[:list][0])
        expect(result[:list][0][0][:password]).to match(/\*+/)
        expect(params[:list][0][0][:password]).to eq('the-password')
      end
    end
  end
end

describe Rollbar::Scrubbers::Params::ATTACHMENT_CLASSES do
  it 'has the correct values' do
    expect(described_class).to be_eql(%w[ActionDispatch::Http::UploadedFile
                                         Rack::Multipart::UploadedFile].freeze)
  end
end

describe Rollbar::Scrubbers::Params::SKIPPED_CLASSES do
  it 'has the correct values' do
    expect(described_class).to be_eql([Tempfile])
  end
end
