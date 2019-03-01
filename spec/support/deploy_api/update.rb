require 'rack/request'

module DeployAPI
  class Update < ::RollbarAPI
    protected
    
    def valid_data?(json, request)
      status?(json) && deploy_id?(request) && access_token?(request)
    end
    
    def status?(json)
      !!json['status']
    end
    
    def deploy_id?(request)
      !!request.env["PATH_INFO"].match(/api\/[0-9]\/deploy\/([0-9]+)/)
    end
    
    def access_token?(request)
      !!CGI.parse(request.env["QUERY_STRING"])['access_token']
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
