require 'capistrano'

module Rollbar
  # Deploy Tracking API wrapper module
  module Deploy
    ENDPOINT = 'https://api.rollbar.com/api/1/deploy/'.freeze

    def self.report(
      access_token:,
      environment:,
      revision:,
      rollbar_username: nil,
      local_username: nil,
      comment: nil,
      status: 'started',
      proxy: nil,
      dry_run: false
    )

      uri = URI.parse(::Rollbar::Deploy::ENDPOINT)

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = ::JSON.dump(
        :access_token => access_token,
        :environment => environment,
        :revision => revision,
        :rollbar_username => rollbar_username,
        :local_username => local_username,
        :comment => comment,
        :status => status.to_s
      )

      result = send_request(uri, proxy, request, dry_run)

      result[:deploy_id] = JSON.parse(result[:response].body)['data']['deploy_id'] if result[:response].is_a? Net::HTTPSuccess

      result
    end

    def self.update(
      deploy_id:,
      access_token:,
      status:,
      comment: nil,
      proxy: nil,
      dry_run: false
    )

      uri = URI.parse(
        ::Rollbar::Deploy::ENDPOINT +
        deploy_id.to_s +
        '?access_token=' + access_token
      )

      request = Net::HTTP::Patch.new(uri.request_uri)
      request.body = ::JSON.dump(
        :status => status.to_s,
        :comment => comment
      )

      send_request(uri, proxy, request, dry_run)
    end

    def self.send_request(uri, proxy, request, dry_run)
      Net::HTTP.start(uri.host, uri.port, proxy, :use_ssl => true) do |http|
        result = {
          :request_info => uri.inspect + ': ' + request.body,
          :request => request
        }

        unless dry_run
          response = http.request(request)

          result[:response] = response
          result[:response_info] =
            response.code + '; ' +
            response.message + '; ' +
            response.body.delete!("\n")
        end

        result
      end
    end
  end
end
