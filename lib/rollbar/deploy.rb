require 'capistrano'

module Rollbar
  # Deploy Tracking API wrapper module
  module Deploy
    ENDPOINT = 'https://api.rollbar.com/api/1/deploy/'.freeze

    def self.report(opts = {}, access_token:, environment:, revision:)
      opts[:status] ||= :started
      
      uri = URI.parse(::Rollbar::Deploy::ENDPOINT)

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = ::JSON.dump({
        :access_token => access_token,
        :environment => environment,
        :revision => revision
      }.merge(opts))

      result = send_request(opts, :uri => uri, :request => request)

      result[:deploy_id] = JSON.parse(result[:response].body)['data']['deploy_id'] if result[:response].is_a? Net::HTTPSuccess

      result
    end

    def self.update(opts = {}, deploy_id:, access_token:, status:)
      uri = URI.parse(
        ::Rollbar::Deploy::ENDPOINT +
        deploy_id.to_s +
        '?access_token=' + access_token
      )

      request = Net::HTTP::Patch.new(uri.request_uri)
      request.body = ::JSON.dump(
        :status => status.to_s,
        :comment => opts[:comment]
      )

      send_request(opts, :uri => uri, :request => request)
    end

    def self.send_request(opts = {}, uri:, request:)
      Net::HTTP.start(uri.host, uri.port, opts[:proxy], :use_ssl => true) do |http|
        result = {
          :request_info => uri.inspect + ': ' + request.body,
          :request => request
        }

        unless opts[:dry_run]
          result[:response] = http.request(request)
          result[:response_info] = result[:response].code + '; ' + result[:response].message + '; ' + result[:response].body.delete!("\n")
        end

        result
      end
    end
  end
end
