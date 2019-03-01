require 'rack/request'

module DeployAPI
  class Report < ::RollbarAPI
    protected
    
    def valid_data?(json)
      !!json['environment'] && !!json['revision'] && super(json)
    end
  
    def success_body(json)
      {
        data: {
          deploy_id: rand(1..1000)
        }
      }.to_json
    end
  end
end
