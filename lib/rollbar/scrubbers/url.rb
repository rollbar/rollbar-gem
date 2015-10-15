require 'uri'
require 'cgi'

module Rollbar
  module Scrubbers
    class URL
      attr_reader :regex
      attr_reader :scrub_user
      attr_reader :scrub_password

      def initialize(options = {})
        @regex = build_regex(options[:scrub_fields])
        @scrub_user = options[:scrub_user]
        @scrub_password = options[:scrub_password]
      end

      def call(url)
        uri = URI(url)

        uri.user = filter_user(uri.user)
        uri.password = filter_password(uri.password)
        uri.query = filter_query(uri.query)

        uri.to_s
      end

      private

      # Builds a regex to match with any of the received fields.
      # The built regex will also match array params like 'user_ids[]'.
      def build_regex(fields)
        fields_or = fields.map { |field| "#{field}(\\[\\])?" }.join('|')

        Regexp.new("^#{fields_or}$")
      end

      def filter_user(user)
        scrub_user && user ? filtered_value : user
      end

      def filter_password(password)
        scrub_password && password ? filtered_value : password
      end

      def filter_query(query)
        return query unless query

        params = URI.decode_www_form(query)

        encoded_query = URI.encode_www_form(filter_query_params(params))

        # We want this to rebuild array params like foo[]=1&foo[]=2
        CGI.unescape(encoded_query)
      end

      def filter_query_params(params)
        params.map do |key, value|
          [key, filter_key?(key) ? filtered_value : value]
        end
      end

      def filter_key?(key)
        !!(key =~ regex)
      end

      def filtered_value
        '*'
      end
    end
  end
end
