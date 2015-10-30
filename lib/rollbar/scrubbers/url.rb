require 'cgi'
require 'uri'

require 'rollbar/language_support'

module Rollbar
  module Scrubbers
    class URL
      attr_reader :regex
      attr_reader :scrub_user
      attr_reader :scrub_password
      attr_reader :randomize_scrub_length

      def initialize(options = {})
        @regex = build_regex(options[:scrub_fields])
        @scrub_user = options[:scrub_user]
        @scrub_password = options[:scrub_password]
        @randomize_scrub_length = options.fetch(:randomize_scrub_length, true)
      end

      def call(url)
        return url unless Rollbar::LanguageSupport.can_scrub_url?

        uri = URI.parse(url)

        uri.user = filter_user(uri.user)
        uri.password = filter_password(uri.password)
        uri.query = filter_query(uri.query)

        uri.to_s
      rescue
        url
      end

      private

      # Builds a regex to match with any of the received fields.
      # The built regex will also match array params like 'user_ids[]'.
      def build_regex(fields)
        fields_or = fields.map { |field| "#{field}(\\[\\])?" }.join('|')

        Regexp.new("^#{fields_or}$")
      end

      def filter_user(user)
        scrub_user && user ? filtered_value(user) : user
      end

      def filter_password(password)
        scrub_password && password ? filtered_value(password) : password
      end

      def filter_query(query)
        return query unless query

        params = decode_www_form(query)

        encoded_query = encode_www_form(filter_query_params(params))

        # We want this to rebuild array params like foo[]=1&foo[]=2
        CGI.unescape(encoded_query)
      end

      def decode_www_form(query)
        URI.decode_www_form(query)
      end

      def encode_www_form(params)
        URI.encode_www_form(params)
      end

      def filter_query_params(params)
        params.map do |key, value|
          [key, filter_key?(key) ? filtered_value(value) : value]
        end
      end

      def filter_key?(key)
        !!(key =~ regex)
      end

      def filtered_value(value)
        if randomize_scrub_length
          random_filtered_value
        else
          '*' * (value.length rescue 8)
        end
      end

      def random_filtered_value
        '*' * (rand(5) + 3)
      end
    end
  end
end
