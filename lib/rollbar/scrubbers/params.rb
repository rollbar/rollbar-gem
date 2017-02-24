require 'tempfile'
require 'rollbar/scrubbers'

module Rollbar
  module Scrubbers
    # This class contains the logic to scrub the receive parameters. It will
    # scrub the parameters matching Rollbar.configuration.scrub_fields Array.
    # Also, if that configuration option is se to :scrub_all, it will scrub all
    # received parameters
    class Params
      SKIPPED_CLASSES = [::Tempfile]
      ATTACHMENT_CLASSES = %w(ActionDispatch::Http::UploadedFile Rack::Multipart::UploadedFile).freeze
      SCRUB_ALL = :scrub_all

      def self.call(*args)
        new.call(*args)
      end

      def call(options = {})
        params = options[:params]
        return {} unless params

        config = options[:config]
        extra_fields = options[:extra_fields]

        scrub(params, build_scrub_options(config, extra_fields))
      end

      private

      def build_scrub_options(config, extra_fields)
        ary_config = Array(config)

        {
          :fields_regex => build_fields_regex(ary_config, extra_fields),
          :scrub_all => ary_config.include?(SCRUB_ALL)
        }
      end

      def build_fields_regex(config, extra_fields)
        fields = config.find_all { |f| f.is_a?(String) || f.is_a?(Symbol) }
        fields += Array(extra_fields)

        return unless fields.any?

        Regexp.new(fields.map { |val| Regexp.escape(val.to_s).to_s }.join('|'), true)
      end

      def scrub(params, options)
        fields_regex = options[:fields_regex]
        scrub_all = options[:scrub_all]

        return scrub_array(params, options) if params.is_a?(Array)

        should_scrub = ->(key) { scrub_all || fields_regex && fields_regex =~ Rollbar::Encoding.encode(key).to_s }

        params.to_hash.inject({}) do |result, (key, value)|
          if should_scrub.call(key)
            result[key] = Rollbar::Scrubbers.scrub_value(value)
          elsif value.is_a?(Hash)
            result[key] = scrub(value, options)
          elsif value.is_a?(Array)
            result[key] = scrub_array(value, options)
          elsif skip_value?(value)
            result[key] = "Skipped value of class '#{value.class.name}'"
          elsif should_scrub.call(key)
            result[key] = Rollbar::Scrubbers.scrub_value(value)
          else
            result[key] = rollbar_filtered_param_value(value)
          end

          result
        end
      end

      def scrub_array(array, options)
        array.map do |value|
          value.is_a?(Hash) ? scrub(value, options) : rollbar_filtered_param_value(value)
        end
      end

      def rollbar_filtered_param_value(value)
        if ATTACHMENT_CLASSES.include?(value.class.name)
          begin
            attachment_value(value)
          rescue
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
