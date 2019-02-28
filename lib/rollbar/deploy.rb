module Rollbar
  # Deploy Tracking API wrapper module
  module Deploy
    ENDPOINT = 'https://api.rollbar.com/api/1/deploy/'.freeze

    def self.report(opts = {}, access_token:, environment:, revision:)
      return {} unless access_token && !access_token.empty?

      opts[:status] ||= :started

      uri = ::URI.parse(::Rollbar::Deploy::ENDPOINT)

      request = ::Net::HTTP::Post.new(uri.request_uri)
      request.body = ::JSON.dump({
        :access_token => access_token,
        :environment => environment,
        :revision => revision
      }.merge(opts))

      send_request(opts, :uri => uri, :request => request)
    end

    def self.update(opts = {}, deploy_id:, access_token:, status:)
      return {} unless access_token && !access_token.empty?

      uri = ::URI.parse(
        ::Rollbar::Deploy::ENDPOINT +
        deploy_id.to_s +
        '?access_token=' + access_token
      )

      request = ::Net::HTTP::Patch.new(uri.request_uri)
      request.body = ::JSON.dump(:status => status.to_s, :comment => opts[:comment])

      send_request(opts, :uri => uri, :request => request)
    end

    class << self
      private

      def send_request(opts = {}, uri:, request:)
        ::Net::HTTP.start(uri.host, uri.port, opts[:proxy], :use_ssl => true) do |http|
          build_result(
            :uri => uri,
            :request => request,
            :response => opts[:dry_run] ? nil : http.request(request)
          )
        end
      end

      def build_result(uri:, request:, response: nil)
        result = {
          :request_info => uri.inspect + ': ' + request.body,
          :request => request,
          :response => response
        }

        unless result[:response].nil?
          result.merge!(::JSON.parse(result[:response].body, :symbolize_names => true))
          result[:response_info] = build_response_info(result[:response])
        end

        result[:success] = result[:response].is_a?(::Net::HTTPSuccess) &&
                            result[:response].code === "200" &&
                            (result.has_key?(:err) ? result[:err] === 0 : true)

        result
      end

      def build_response_info(response)
        response.code + '; ' + response.message + '; ' + response.body.delete("\n")
      end
    end
  end
end
