require 'rack/request'

module DeployAPI
  class Report < ::RollbarAPI
    protected

    def valid_data?(json, request)
      !!json['environment'] && !!json['revision'] && super(json, request)
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
