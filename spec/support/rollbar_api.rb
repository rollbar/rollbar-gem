require 'rack/request'

class RollbarAPI
  def call(env)
    request = Rack::Request.new(env)
    json = JSON.parse(request.body.read)

    return bad_request(json) unless access_token?(json)

    success(json)
  end

  private

  def response_headers
    {
      'Content-Type' => 'application/json'
    }
  end

  def access_token?(json)

    !!json['access_token']
  end

  def bad_request(json)
    # We don't have for now any test doing bad requests
    # so raise here in order to detect that scenario
    raise


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
