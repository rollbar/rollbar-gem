require 'rack/request'

class RollbarAPI
  def call(env)
    request = Rack::Request.new(env)
    json = JSON.parse(request.body.read)

    return bad_request(json) unless invalid_data?(json)

    success(json)
  end

  protected

  def response_headers
    {
      'Content-Type' => 'application/json'
    }
  end

  def invalid_data?(json)
    !!json['access_token']
  end

  def bad_request(json)
    [400, response_headers, [bad_request_body]]
  end

  def success(json)
    [200, response_headers, [success_body(json)]]
  end

  def bad_request_body
    result(1, nil, 'bad request')
  end

  def success_body(json)
    result(0, {
      :id => rand(1_000_000),
      :uuid => json['data']['uuid']
    }, nil)
  end

  def result(err, body, message)
    {
      :err => err,
      :result => body,
      :message => message
    }.to_json
  end
end
