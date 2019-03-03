require 'spec_helper'
require 'rollbar/deploy'

describe ::Rollbar::Deploy do
  let(:access_token) { '123' }
  let(:dry_run) { false }
  let(:proxy) { :ENV }

  shared_examples 'request fails' do
    it 'sets success in result to false' do
      expect(@result[:success]).to eq(false)
    end
  end

  shared_examples 'request success' do
    it 'sets success in result to true' do
      expect(@result[:success]).to eq(true)
    end
  end

  shared_examples 'builds the response info string' do |regex|
    it 'builds the response info string' do
      expect(@result[:response_info]).to match(regex)
    end
  end

  shared_context 'with proxy' do
    context 'with proxy' do
      let(:proxy) { 'some proxy' }

      it 'uses provided proxy' do
        expect(::Net::HTTP).to have_received(:start).with(
          anything, anything, proxy, hash_including(:use_ssl => true)
        )
      end
    end
  end

  shared_context 'access token not authorized' do
    context 'when access token is not authorized' do
      let(:access_token) { ::RollbarAPI::UNAUTHORIZED_ACCESS_TOKEN }

      include_examples 'request fails'
    end
  end

  shared_examples 'deploy API request' do
    context 'without access token' do
      let(:access_token) { nil }

      it 'returns an empty hash' do
        expect(@result).to be_empty
      end
    end

    it 'adds the request object to the result' do
      expect(@result[:request]).to be_kind_of(::Net::HTTPRequest)
    end

    # depends on let(:expected_request_info_url)
    it 'builds the request info string' do
      expect(@result[:request_info]).to match(
        %r{#{Regexp.escape(expected_request_info_url)}.*#{Regexp.escape(::JSON.dump(expected_request_data))}}
      )
    end

    # depends on let(:expected_request_data)
    it 'adds data to the request' do
      data = ::JSON.parse(@result[:request].body)

      expected_request_data.each do |key, value|
        expect(data[key.to_s]).to eq(value.to_s)
      end
    end
  end

  shared_examples 'valid deploy API request' do |response_string_regex|
    it 'adds the response object to the result' do
      expect(@result[:response]).to be_kind_of(::Net::HTTPResponse)
    end

    include_examples 'builds the response info string', response_string_regex
    include_examples 'request success'
    include_context 'with proxy'
    include_context 'access token not authorized'
  end

  shared_examples 'invalid deploy API request' do |response_string_regex|
    include_examples 'builds the response info string', response_string_regex
    include_examples 'request fails'
  end

  shared_context 'in dry run' do
    context 'in dry run' do
      let(:dry_run) { true }

      include_examples 'request success'

      it "doesn't send the request" do
        WebMock.should_not have_requested(:post, ::Rollbar::Deploy::ENDPOINT).once
      end
    end
  end

  before(:each) do
    allow(::Net::HTTP).to receive(:start).and_call_original
  end

  describe '.report' do
    let(:environment) { 'test' }
    let(:revision) { 'sha1' }

    let(:rollbar_user) { 'foo' }
    let(:rollbar_comment) { 'bar' }
    let(:rollbar_token) { 'baz' }
    let(:rollbar_env) { 'foobar' }
    let(:status) { :started }

    before(:each) do
      @result = subject.report(
        {
          :rollbar_username => rollbar_user,
          :local_username => rollbar_user,
          :comment => rollbar_comment,
          :status => status,
          :proxy => proxy,
          :dry_run => dry_run
        },
        :access_token => access_token,
        :environment => environment,
        :revision => revision
      )
    end

    it_behaves_like 'deploy API request' do
      let(:expected_request_data) do
        {
          :access_token => access_token,
          :environment => environment,
          :revision => revision,
          :rollbar_username => rollbar_user,
          :local_username => rollbar_user,
          :comment => rollbar_comment,
          :status => status
        }
      end

      let(:expected_request_info_url) { ::Rollbar::Deploy::ENDPOINT }
    end

    context 'with valid request data' do
      it_behaves_like 'valid deploy API request', /^200; OK; {"data":{"deploy_id":[0-9]+}}/

      it 'adds deploy id to the result' do
        expect(@result[:data][:deploy_id].to_s).to match(/[0-9]+/)
      end
    end

    context 'with invalid request data' do
      let(:environment) { nil }
      let(:revision) { nil }

      it_behaves_like 'invalid deploy API request', /^400; Bad Request; \{.*}$/
    end

    include_context 'in dry run'
  end

  describe '.update' do
    let(:deploy_id) { rand(1..1000) }
    let(:status) { :succeeded }
    let(:rollbar_comment) { 'foo' }

    before(:each) do
      @result = subject.update(
        {
          :comment => rollbar_comment,
          :proxy => proxy,
          :dry_run => dry_run
        },
        :access_token => access_token,
        :deploy_id => deploy_id,
        :status => status
      )
    end

    it_behaves_like 'deploy API request' do
      let(:expected_request_data) do
        {
          :status => status,
          :comment => rollbar_comment
        }
      end

      let(:expected_request_info_url) do
        ::Rollbar::Deploy::ENDPOINT +
          "#{deploy_id}?access_token=#{access_token}"
      end
    end

    context 'with valid request data' do
      it_behaves_like 'valid deploy API request', /^200; OK; {.*\"id\":[0-9]+.*/
    end

    context 'with invalid request data' do
      let(:status) { nil }
      let(:deploy_id) { nil }

      it_behaves_like 'invalid deploy API request', /^400; Bad Request; \{.*}$/
    end

    include_context 'in dry run'
  end
end
