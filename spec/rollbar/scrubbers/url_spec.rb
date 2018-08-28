require 'spec_helper'
require 'rollbar/language_support'
require 'rollbar/scrubbers/url'

describe Rollbar::Scrubbers::URL do
  let(:options) do
    options = {
      :url => url,
      :scrub_fields => [:password, :secret],
      :scrub_user => false,
      :scrub_password => false,
      :randomize_scrub_length => true
    }
      
    if defined? whitelist
      options[:whitelist] = whitelist
    end
    
    options
  end

  describe '#call' do
    context 'cannot scrub URLs' do
      next if Rollbar::LanguageSupport.can_scrub_url?

      let(:url) { 'http://user:password@foo.com/some-interesting-path#fragment' }

      it 'returns the URL without any change' do
        expect(subject.call(options)).to be_eql(url)
      end
    end

    context 'with ruby different from 1.8' do
      next unless Rollbar::LanguageSupport.can_scrub_url?

      context 'without data to be scrubbed' do
        let(:url) { 'http://user:password@foo.com/some-interesting-path#fragment' }

        it 'returns the URL without any change' do
          expect(subject.call(options)).to be_eql(url)
        end

        context 'with arrays in params' do
          let(:url) { 'http://user:password@foo.com/some-interesting-path?foo[]=1&foo[]=2' }

          it 'returns the URL without any change' do
            expect(subject.call(options)).to be_eql(url)
          end
        end
      end

      context 'scrubbing user and password' do
        let(:options) do
          {
            :url => url,
            :scrub_fields => [],
            :scrub_password => true,
            :scrub_user => true
          }
        end

        let(:url) { 'http://user:password@foo.com/some-interesting-path#fragment' }

        it 'returns the URL without any change' do
          expected_url = /http:\/\/\*{3,8}:\*{3,8}@foo.com\/some-interesting\-path#fragment/

          expect(subject.call(options)).to match(expected_url)
        end
      end

      context 'with params to be filtered' do
        let(:url) { 'http://foo.com/some-interesting-path?foo=bar&password=mypassword&secret=somevalue#fragment' }

        it 'returns the URL with some params filtered' do
          expected_url = /http:\/\/foo.com\/some-interesting-path\?foo=bar&password=\*{3,8}&secret=\*{3,8}#fragment/

          expect(subject.call(options)).to match(expected_url)
        end

        context 'having array params' do
          let(:url) { 'http://foo.com/some-interesting-path?foo=bar&password[]=mypassword&password[]=otherpassword&secret=somevalue#fragment' }

          it 'returns the URL with some params filtered' do
            expected_url = /http:\/\/foo.com\/some-interesting-path\?foo=bar&password\[\]=\*{3,8}&password\[\]=\*{3,8}&secret=\*{3,8}#fragment/

            expect(subject.call(options)).to match(expected_url)
          end
        end
      end

      context 'with no-random scrub length' do
        let(:options) do
          {
            :url => url,
            :scrub_fields => [:password, :secret],
            :scrub_user => false,
            :scrub_password => false,
            :randomize_scrub_length => false
          }
        end
        let(:password) { 'longpasswordishere' }
        let(:url) { "http://foo.com/some-interesting-path?foo=bar&password=#{password}#fragment" }

        it 'scrubs with same length than the scrubbed param' do
          expected_url = /http:\/\/foo.com\/some-interesting-path\?foo=bar&password=\*{#{password.length}}#fragment/

          expect(subject.call(options)).to match(expected_url)
        end
      end

      context 'with malformed URL or not able to be parsed' do
        let(:url) { '\this\is\not\a\valid\url' }
        before { reconfigure_notifier }

        it 'return the same url' do
          expect(Rollbar.logger).to receive(:error).and_call_original
          expect(subject.call(options)).to be_eql(url)
        end
      end

      context 'with URL with spaces and arrays' do
        let(:url) do
          'https://server.com/api/v1/assignments/4430038?user_id=1&assignable_id=2&starts_at=Wed%20Jul%2013%202016%2000%3A00%3A00%20GMT-0700%20(PDT)&ends_at=Fri%20Jul%2029%202016%2000%3A00%3A00%20GMT-0700%20(PDT)&allocation_mode=hours_per_day&percent=&fixed_hours=&hours_per_day=0&auth=REMOVED&___uidh=2228207862&password[]=mypassword'
        end
        let(:options) do
          {
            :url => url,
            :scrub_fields => [:passwd, :password, :password_confirmation, :secret, :confirm_password, :secret_token, :api_key, :access_token, :auth, :SAMLResponse, :password, :auth],
            :scrub_user => true,
            :scrub_password => true,
            :randomize_scrub_length => true
          }
        end

        it 'doesnt logs error' do
          expect(Rollbar.logger).not_to receive(:error).and_call_original
          subject.call(options)
        end
      end
    end
    
    context 'in whitelist mode' do
      
      let(:whitelist) { true }
      
      context 'with ruby different from 1.8' do
        next unless Rollbar::LanguageSupport.can_scrub_url?
        
        context 'cannot scrub URLs' do
    
          let(:url) { 'http://user:password@foo.com/some-interesting-path#fragment' }
    
          it 'returns the URL without any change' do
            expect(subject.call(options)).to be_eql(url)
          end
        end
          
        context 'scrubbing user and password' do
          
          let(:options) do
            {
              :url => url,
              :scrub_fields => [],
              :scrub_password => true,
              :scrub_user => true,
              :whitelist => whitelist
            }
          end
  
          let(:url) { 'http://user:password@foo.com/some-interesting-path#fragment' }
  
          it 'returns the URL without any change' do
            expected_url = /http:\/\/\*{3,8}:\*{3,8}@foo.com\/some-interesting\-path#fragment/
  
            expect(subject.call(options)).to match(expected_url)
          end
        end
        
        context 'with params to be filtered' do
          let(:options) do
            {
              :url => url,
              :scrub_fields => [:dont_scrub],
              :scrub_password => false,
              :scrub_user => false,
              :whitelist => whitelist
            }
          end
          
          let(:url) { 'http://foo.com/some-interesting-path?foo=bar&password=mypassword&secret=somevalue&dont_scrub=foo#fragment' }
  
          it 'returns the URL with some params filtered' do
            expected_url = /http:\/\/foo.com\/some-interesting-path\?foo=\*{3,8}&password=\*{3,8}&secret=\*{3,8}&dont_scrub=foo#fragment/
            
            expect(subject.call(options)).to match(expected_url)
          end
  
          context 'having array params' do
            let(:url) { 'http://foo.com/some-interesting-path?foo=bar&password[]=mypassword&password[]=otherpassword&secret=somevalue&dont_scrub=foo#fragment' }
  
            it 'returns the URL with some params filtered' do
              expected_url = /http:\/\/foo.com\/some-interesting-path\?foo=\*{3,8}&password\[\]=\*{3,8}&password\[\]=\*{3,8}&secret=\*{3,8}&dont_scrub=foo#fragment/
  
              expect(subject.call(options)).to match(expected_url)
            end
          end
        end
      end
    end
  end
end
