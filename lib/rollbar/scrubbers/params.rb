require 'tempfile'
require 'rollbar/scrubbers'
require 'rollbar/util/reference_tracker'

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

        @tracker = Rollbar::Util::ReferenceTracker.new

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
        fields = config.find_all { |f| field_name?(f) }
        # extra_fields may hold Regexps, e.g. Rails' action_dispatch.parameter_filter,
        # which is a single precompiled Regexp when precompile_filter_parameters is on.
        fields += Array(extra_fields).find_all { |f| f.is_a?(Regexp) || field_name?(f) }

        return unless fields.any?

        Regexp.new(fields.map do |val|
                     val.is_a?(Regexp) ? val.to_s : Regexp.escape(val.to_s)
                   end.join('|'), true)
      end

      def field_name?(field)
        field.is_a?(String) || field.is_a?(Symbol)
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

      # Always returns a new object and never modifies `params`. A container
      # referenced more than once gets its own copy at each occurrence, so a
      # later in-place change to one copy (e.g. Util.deep_merge in
      # Item#build_extra) can't show up under the other keys. In a cycle, the
      # container maps to the copy being built, so the caller's original object
      # never leaks into the payload.
      def scrub(params, options)
        return scrub_array(params, options) if params.is_a?(Array)

        copy_container(params, {}) do |result|
          to_scrubbable_hash(params).each do |key, value|
            result[key] = scrub_hash_value(key, value, options)
          end
        end
      end

      def scrub_hash_value(key, value, options)
        encoded_key = Rollbar::Encoding.encode(key).to_s
        whitelisted = options[:whitelist] === encoded_key

        if (options[:fields_regex] === encoded_key) && !whitelisted
          scrub_value(value)
        elsif hash_like?(value)
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
        copy_container(array, []) do |result|
          array.each do |value|
            result << if hash_like?(value) || value.is_a?(Array)
                        scrub(value, options)
                      else
                        rollbar_filtered_param_value(value)
                      end
          end
        end
      end

      # Yields `copy` to be filled in, registered first so a cycle maps to it.
      def copy_container(container, copy)
        return @tracker.copy_of(container) if @tracker.circular?(container)
        unless @tracker.copy_allowed?(container)
          return Rollbar::Util::ReferenceTracker::REPEATED_REFERENCE_MARKER
        end

        @tracker.track(container, copy) { yield copy }
        copy
      end

      # Objects that implement implicit Hash conversion without being a Hash,
      # e.g. ActionController::Parameters, must be recursed into too.
      def hash_like?(value)
        value.is_a?(Hash) || value.respond_to?(:to_hash)
      end

      def to_scrubbable_hash(value)
        return value if value.is_a?(Hash)
        # ActionController::Parameters#to_hash raises for unpermitted params.
        return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)

        value.to_hash
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
