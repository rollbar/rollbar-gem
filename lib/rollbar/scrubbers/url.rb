require 'cgi'
require 'uri'

require 'rollbar/language_support'

module Rollbar
  module Scrubbers
    class URL
      def self.call(*args)
        new.call(*args)
      end

      def call(options = {})
        url = options[:url]
        return url unless Rollbar::LanguageSupport.can_scrub_url?

        filter(url,
               build_regex(options[:scrub_fields], options[:whitelist] || []),
               options[:scrub_user],
               options[:scrub_password],
               options.fetch(:randomize_scrub_length, true))
      rescue => e
        Rollbar.logger.error("[Rollbar] There was an error scrubbing the url: #{e}, options: #{options.inspect}")
        url
      end

      private

      def filter(url, regex, scrub_user, scrub_password, randomize_scrub_length)
        uri = URI.parse(url)

        uri.user = filter_user(uri.user, scrub_user, randomize_scrub_length)
        uri.password = filter_password(uri.password, scrub_password, randomize_scrub_length)
        uri.query = filter_query(uri.query, regex, randomize_scrub_length)

        uri.to_s
      end

      # Builds a regex to match with any of the received fields.
      # The built regex will also match array params like 'user_ids[]'.
      def build_regex(fields, whitelist)
        fields_or = fields.reject { |f| whitelist.include? f }.map { |field| "#{field}(\\[\\])?" }.join('|')

        Regexp.new("^#{fields_or}$")
      end

      def filter_user(user, scrub_user, randomize_scrub_length)
        scrub_user && user ? filtered_value(user, randomize_scrub_length) : user
      end

      def filter_password(password, scrub_password, randomize_scrub_length)
        scrub_password && password ? filtered_value(password, randomize_scrub_length) : password
      end

      def filter_query(query, regex, randomize_scrub_length)
        return query unless query

        params = decode_www_form(query)

        encoded_query = encode_www_form(filter_query_params(params, regex, randomize_scrub_length))

        # We want this to rebuild array params like foo[]=1&foo[]=2
        URI.escape(CGI.unescape(encoded_query))
      end

      def decode_www_form(query)
        URI.decode_www_form(query)
      end

      def encode_www_form(params)
        URI.encode_www_form(params)
      end

      def filter_query_params(params, regex, randomize_scrub_length)
        params.map do |key, value|
          [key, filter_key?(key, regex) ? filtered_value(value, randomize_scrub_length) : value]
        end
      end

      def filter_key?(key, regex)
        !!(key =~ regex)
      end

      def filtered_value(value, randomize_scrub_length)
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
