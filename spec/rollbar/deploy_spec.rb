require 'spec_helper'
require 'rollbar/deploy'

describe ::Rollbar::Deploy do
  
  describe '.report' do
    
    let(:access_token) { '123' }
    let(:environment) { 'test' }
    let(:revision) { 'sha1' }
    
    let(:rollbar_user) { 'foo' }
    let(:rollbar_comment) { 'bar' }
    let(:rollbar_token) { 'baz' }
    let(:rollbar_env) { 'foobar' }
    let(:proxy) { :ENV }
    
    let(:dry_run) { false }
      
    before(:each) do
      allow(::Net::HTTP).to receive(:start).and_call_original
      
      @result = subject.report(
        {
          :rollbar_username => rollbar_user,
          :local_username => rollbar_user,
          :comment => rollbar_comment,
          :proxy => proxy
        },
        access_token: access_token,
        environment: environment,
        revision: revision
      )
    end
    
    shared_examples 'request fails' do
      it "sets success in result to false" do
        expect(@result[:success]).to eq(false)
      end
    end
    
    shared_examples 'request success' do
      it "sets success in result to true" do
        expect(@result[:success]).to eq(true)
      end
    end
    
    shared_examples 'builds the response info string' do |regex|
      it "builds the response info string" do
        expect(@result[:response_info]).to match(regex)
      end
    end
    
    context "with valid request data" do
      
      it "adds the request object to the result" do
        expect(@result[:request]).to be_kind_of(::Net::HTTPRequest)
      end
    
      it "adds the response object to the result" do
        expect(@result[:response]).to be_kind_of(::Net::HTTPResponse)
      end  
    
      it "builds the request info string" do
        expect(@result[:request_info]).to eq(
          "#<URI::HTTPS #{::Rollbar::Deploy::ENDPOINT}>: " +
          ::JSON.dump({
            access_token: access_token,
            environment: environment,
            revision: revision,
            rollbar_username: rollbar_user,
            local_username: rollbar_user,
            comment: rollbar_comment,
            status: 'started'
          })
        )
      end
    
      it "adds required data to the request" do
        data = ::JSON.parse(@result[:request].body)
        expect(data['access_token']).to eq(access_token)
        expect(data['environment']).to eq(environment)
        expect(data['revision']).to eq(revision)
      end
      
      it "adds optional data to the request" do
        data = ::JSON.parse(@result[:request].body)
        expect(data['rollbar_username']).to eq(rollbar_user)
        expect(data['local_username']).to eq(rollbar_user)
        expect(data['comment']).to eq(rollbar_comment)
        expect(data['status']).to eq ('started')
      end
      
      include_examples 'builds the response info string', /^200; OK; {"data":{"deploy_id":[0-9]+}}/
      
      include_examples 'request success'
      
      it "adds deploy id to the result" do
        expect(@result[:data][:deploy_id].to_s).to match(/[0-9]+/)
      end
      
      context "with proxy" do
        let(:proxy) { "some proxy" }
        
        it "uses provided proxy" do
          expect(::Net::HTTP).to have_received(:start).with(
            anything, anything, proxy, hash_including(:use_ssl => true)
          )
        end
      end
      
      context "when access token is not authorized" do
        let(:access_token) { ::RollbarAPI::UNAUTHORIZED_ACCESS_TOKEN }
        
        include_examples 'request fails'
      end
    end
    
    context "with invalid request data" do
      
      let(:environment) { nil }
      let(:revision) { nil }
      
      include_examples 'builds the response info string', /^400; Bad Request; \{.*}$/
      
      include_examples 'request fails'
    end
    
    context "in dry run" do
      let(:dry_run) { true }
      
      include_examples 'request success'
      
      it "doesn't actually send the request" do
        
      end
    end
    
    context 'without access token' do
      
      let(:access_token) { nil }
      
      it "returns an empty hash" do
        expect(@result).to be_empty
      end
    end
  end
  
  describe '.update' do
    
  end
end