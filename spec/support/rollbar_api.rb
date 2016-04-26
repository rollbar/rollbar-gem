require 'rack/request'

class RollbarAPI
  def call(env)
    request = Rack::Request.new(env)

    success(request)
  end

  def success(request)
    headers = {
      'Content-Type' => 'application/json'
    }
    [200, headers, [success_body(request)]]
  end

  def success_body(request)
    json = JSON.parse(request.body.read)

    {
      :err => 0,
      :result => {
        :id => rand(1_000_000),
        :uuid => json['data']['uuid']
      }
    }.to_json
  end
end
