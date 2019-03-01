require 'rack/request'

module DeployAPI
  class Update < ::RollbarAPI
    protected
    
    def valid_data?(json, request)
      status?(json) && deploy_id?(request) && access_token?(request)
    end
    
    def authorized?(json, request)
      access_token(request) != UNAUTHORIZED_ACCESS_TOKEN
    end
    
    def status?(json)
      ['started', 'succeeded', 'failed', 'timed_out'].include?(json['status'])
    end
    
    def deploy_id?(request)
      !!deploy_id(request)
    end
    
    def deploy_id(request)
      request.env["PATH_INFO"].match(/api\/[0-9]\/deploy\/([0-9]+)/)[1]
    end
    
    def access_token?(request)
      !!access_token(request)
    end
    
    def access_token(request)
      CGI.parse(request.env["QUERY_STRING"])['access_token'][0] if !CGI.parse(request.env["QUERY_STRING"])['access_token'].empty?
    end
  
    def success_body(json, request)
      {
        err: 0,
        result: {
          username: nil,
          comment: nil,
          user_id: nil,
          start_time: rand(1..1000),
          local_username: nil,
          environment: 'test',
          finish_time: rand(1000..2000),
          status: json['status'],
          project_id: rand(1..1000),
          id: deploy_id(request).to_i,
          revision: 'sha1'
        }
      }.to_json
    end
  end
end
