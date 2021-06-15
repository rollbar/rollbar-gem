require 'json'

module Rollbar
  # Deploy Tracking API wrapper module
  module Deploy
    ENDPOINT = 'https://api.rollbar.com/api/1/deploy/'.freeze

    def self.report(opts, access_token, environment, revision)
      return {} unless access_token && !access_token.empty?

      opts[:status] ||= :started

      uri = ::URI.parse(::Rollbar::Deploy::ENDPOINT)

      request_data = {
        :access_token => access_token,
        :environment => environment,
        :revision => revision
      }.merge(opts)
      request_data.delete(:proxy)
      request_data.delete(:dry_run)

      request = ::Net::HTTP::Post.new(uri.request_uri)
      request.body = ::JSON.dump(request_data)

      send_request(opts, uri, request)
    end

    def self.update(opts, access_token, deploy_id, status)
      return {} unless access_token && !access_token.empty?

      uri = ::URI.parse(
        "#{::Rollbar::Deploy::ENDPOINT}#{deploy_id}?access_token=#{access_token}"
      )

      request = ::Net::HTTP::Patch.new(uri.request_uri)
      request.body = ::JSON.dump(:status => status.to_s, :comment => opts[:comment])

      send_request(opts, uri, request)
    end

    class << self
      private

      def send_request(opts, uri, request)
        ::Net::HTTP.start(uri.host, uri.port, opts[:proxy], :use_ssl => true) do |http|
          build_result(
            uri,
            request,
            opts[:dry_run] ? nil : http.request(request),
            opts[:dry_run]
          )
        end
      end

      def build_result(uri, request, response = nil, dry_run = false)
        result = {}
        result.merge!(request_result(uri, request))
        result.merge!(response_result(response)) unless response.nil?
        result[:success] = success?(result, dry_run)
        result
      end

      def success?(result, dry_run = false)
        return true if dry_run

        result[:response] &&
          result[:response].is_a?(::Net::HTTPSuccess) &&
          result[:response].code == '200' &&
          (result.key?('err') ? result['err'].to_i.zero? : true)
      end

      def request_result(uri, request)
        {
          :request_info => "#{uri.inspect}: #{request.body}",
          :request => request
        }
      end

      def response_result(response)
        code = response.code
        message = response.message
        body = response.body.delete("\n")
        {
          :response => response,
          :response_info => "#{code}; #{message}; #{body}"
        }.merge(::JSON.parse(response.body, :symbolize_names => true))
      end
    end
  end
end
