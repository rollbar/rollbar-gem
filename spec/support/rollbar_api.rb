require 'rack/request'

class RollbarAPI
  UNAUTHORIZED_ACCESS_TOKEN = 'unauthorized'.freeze

  def call(env)
    request = Rack::Request.new(env)
    json = JSON.parse(request.body.read)

    return unauthorized unless authorized?(json, request)

    return bad_request(json) unless valid_data?(json, request)

    success(json, request)
  end

  protected

  def authorized?(_json, request)
    request.env['HTTP_X_ROLLBAR_ACCESS_TOKEN'] != UNAUTHORIZED_ACCESS_TOKEN
  end

  def response_headers
    {
      'Content-Type' => 'application/json'
    }
  end

  def valid_data?(_json, request)
    !!request.env['HTTP_X_ROLLBAR_ACCESS_TOKEN']
  end

  def unauthorized
    [401, response_headers, [unauthorized_body]]
  end

  def bad_request(_json)
    [400, response_headers, [bad_request_body]]
  end

  def success(json, request)
    [200, response_headers, [success_body(json, request)]]
  end

  def unauthorized_body
    result(1, nil, 'invalid access token')
  end

  def bad_request_body
    result(1, nil, 'bad request')
  end

  def success_body(json, _request)
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
