require 'rack/request'
require "#{File.dirname(__FILE__)}/../rollbar_api.rb"

module DeployAPI
  class Update < ::RollbarAPI
    protected

    def valid_data?(json, request)
      status?(json) && deploy_id?(request) && access_token?(request)
    end

    def authorized?(_json, request)
      access_token(request) != UNAUTHORIZED_ACCESS_TOKEN
    end

    def status?(json)
      %w[started succeeded failed timed_out].include?(json['status'])
    end

    def deploy_id?(request)
      !!deploy_id(request)
    end

    def deploy_id(request)
      request.env['PATH_INFO'].match(%r{api/[0-9]/deploy/([0-9]+)})[1]
    end

    def access_token?(request)
      !!access_token(request)
    end

    def access_token(request)
      return if CGI.parse(request.env['QUERY_STRING'])['access_token'].empty?
      CGI.parse(request.env['QUERY_STRING'])['access_token'][0]
    end

    def success_body(json, request)
      {
        :err => 0,
        :result => success_body_result(json, request)
      }.to_json
    end

    def success_body_result(json, request)
      {
        :username => nil,
        :comment => nil,
        :user_id => nil,
        :start_time => rand(1..1000),
        :local_username => nil,
        :environment => 'test',
        :finish_time => rand(1000..2000),
        :status => json['status'],
        :project_id => rand(1..1000),
        :id => deploy_id(request).to_i,
        :revision => 'sha1'
      }
    end
  end
end
