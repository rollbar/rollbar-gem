require 'rack/request'
require "#{File.dirname(__FILE__)}/../rollbar_api.rb"

module DeployAPI
  class Report < ::RollbarAPI
    protected

    def authorized?(json, _request)
      json['access_token'] != UNAUTHORIZED_ACCESS_TOKEN
    end

    def valid_data?(json, _request)
      !!json['environment'] && !!json['revision'] && !!json['access_token']
    end

    def success_body(_json, _request)
      {
        :data => {
          :deploy_id => rand(1..1000)
        }
      }.to_json
    end
  end
end
