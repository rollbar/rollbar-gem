require 'spec_helper'
require 'rollbar/language_support'
require 'rollbar/scrubbers/url'

describe Rollbar::Scrubbers::URL do
  let(:options) do
    { :scrub_fields => [:password, :secret],
      :scrub_user => false,
      :scrub_password => false
    }
  end

  subject { described_class.new(options) }

  describe '#call' do
    context 'cannot scrub URLs' do
      next if Rollbar::LanguageSupport.can_scrub_url?

      let(:url) { 'http://user:password@foo.com/some-interesting-path#fragment' }

      it 'returns the URL without any change' do
        expect(subject.call(url)).to be_eql(url)
      end
    end

    context 'with ruby different from 1.8' do
      next unless Rollbar::LanguageSupport.can_scrub_url?

      context 'without data to be scrubbed' do
        let(:url) { 'http://user:password@foo.com/some-interesting-path#fragment' }

        it 'returns the URL without any change' do
          expect(subject.call(url)).to be_eql(url)
        end

        context 'with arrays in params' do
          let(:url) { 'http://user:password@foo.com/some-interesting-path?foo[]=1&foo[]=2' }

          it 'returns the URL without any change' do
            expect(subject.call(url)).to be_eql(url)
          end
        end
      end

      context 'scrubbing user and password' do
        let(:options) do
          {
            :scrub_fields => [],
            :scrub_password => true,
            :scrub_user => true
          }
        end

        let(:url) { 'http://user:password@foo.com/some-interesting-path#fragment' }

        it 'returns the URL without any change' do
          expected_url = /http:\/\/\*{3,8}:\*{3,8}@foo.com\/some-interesting\-path#fragment/

          expect(subject.call(url)).to match(expected_url)
        end
      end

      context 'with params to be filtered' do
        let(:url) { 'http://foo.com/some-interesting-path?foo=bar&password=mypassword&secret=somevalue#fragment' }

        it 'returns the URL with some params filtered' do
          expected_url = /http:\/\/foo.com\/some-interesting-path\?foo=bar&password=\*{3,8}&secret=\*{3,8}#fragment/

          expect(subject.call(url)).to match(expected_url)
        end

        context 'having array params' do
          let(:url) { 'http://foo.com/some-interesting-path?foo=bar&password[]=mypassword&password[]=otherpassword&secret=somevalue#fragment' }

          it 'returns the URL with some params filtered' do
            expected_url = /http:\/\/foo.com\/some-interesting-path\?foo=bar&password\[\]=\*{3,8}&password\[\]=\*{3,8}&secret=\*{3,8}#fragment/

            expect(subject.call(url)).to match(expected_url)
          end
        end
      end
    end
  end
end
