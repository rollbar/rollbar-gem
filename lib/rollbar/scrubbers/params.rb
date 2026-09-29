require 'tempfile'
require 'rollbar/scrubbers'

module Rollbar
  module Scrubbers
    # This class contains the logic to scrub the received parameters. It will
    # scrub the parameters matching Rollbar.configuration.scrub_fields Array.
    # Also, if that configuration option is set to :scrub_all, it will scrub all
    # received parameters. It will not scrub anything that is in the scrub_whitelist
    # configuration array even if :scrub_all is true.
    class Params
      SKIPPED_CLASSES = [::Tempfile].freeze
      ATTACHMENT_CLASSES = %w[ActionDispatch::Http::UploadedFile
                              Rack::Multipart::UploadedFile].freeze
      SCRUB_ALL = :scrub_all

      def self.call(*args)
        new.call(*args)
      end

      def call(options = {})
        params = options[:params]
        return {} unless params

        @scrubbed_objects = {}.compare_by_identity

        config = options[:config]
        extra_fields = options[:extra_fields]
        whitelist = options[:whitelist] || []

        scrub(params, build_scrub_options(config, extra_fields, whitelist))
      end

      private

      def build_scrub_options(config, extra_fields, whitelist)
        ary_config = Array(config)

        {
          :fields_regex => build_fields_regex(ary_config, extra_fields),
          :scrub_all => ary_config.include?(SCRUB_ALL),
          :whitelist => build_whitelist_regex(whitelist)
        }
      end

      def build_fields_regex(config, extra_fields)
        fields = config.find_all { |f| f.is_a?(String) || f.is_a?(Symbol) }
        fields += Array(extra_fields)

        return unless fields.any?

        Regexp.new(fields.map { |val| Regexp.escape(val.to_s).to_s }.join('|'), true)
      end

      def build_whitelist_regex(whitelist)
        fields = whitelist.find_all do |f|
          f.is_a?(String) || f.is_a?(Symbol) || f.is_a?(Regexp)
        end
        return unless fields.any?

        Regexp.new(fields.map do |val|
                     val.is_a?(Regexp) ? val : /\A#{Regexp.escape(val.to_s)}\z/
                   end.join('|'))
      end

      # Always returns a new object and never modifies `params`. The copy of
      # each container is memoized (and registered before recursing), so a
      # container referenced more than once, or in a cycle, maps to its copy
      # instead of leaking the caller's original object into the payload.
      def scrub(params, options)
        return @scrubbed_objects[params] if @scrubbed_objects.key?(params)
        return scrub_array(params, options) if params.is_a?(Array)

        result = @scrubbed_objects[params] = {}

        params.to_hash.each do |key, value|
          result[key] = scrub_hash_value(key, value, options)
        end

        result
      end

      def scrub_hash_value(key, value, options)
        encoded_key = Rollbar::Encoding.encode(key).to_s
        whitelisted = options[:whitelist] === encoded_key

        if (options[:fields_regex] === encoded_key) && !whitelisted
          scrub_value(value)
        elsif value.is_a?(Hash)
          scrub(value, options)
        elsif options[:scrub_all] && !whitelisted
          scrub_value(value)
        elsif value.is_a?(Array)
          scrub_array(value, options)
        elsif skip_value?(value)
          "Skipped value of class '#{value.class.name}'"
        else
          rollbar_filtered_param_value(value)
        end
      end

      def scrub_array(array, options)
        return @scrubbed_objects[array] if @scrubbed_objects.key?(array)

        result = @scrubbed_objects[array] = []

        array.each do |value|
          nested = value.is_a?(Hash) || value.is_a?(Array)
          result << (nested ? scrub(value, options) : rollbar_filtered_param_value(value))
        end

        result
      end

      def scrub_value(value)
        Rollbar::Scrubbers.scrub_value(value)
      end

      def rollbar_filtered_param_value(value)
        if ATTACHMENT_CLASSES.include?(value.class.name)
          begin
            attachment_value(value)
          rescue StandardError
            'Uploaded file'
          end
        else
          value
        end
      end

      def attachment_value(value)
        {
          :content_type => value.content_type,
          :original_filename => value.original_filename,
          :size => value.tempfile.size
        }
      end

      def skip_value?(value)
        SKIPPED_CLASSES.any? { |klass| value.is_a?(klass) }
      end
    end
  end
end
