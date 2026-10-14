require 'rollbar/scrubbers/params'

module Rollbar
  module Delayed
    class JobData
      attr_reader :job

      def initialize(job)
        @job = job
      end

      def to_hash
        job_data = extract_job_data

        handler_parent = job_data['job'] || job_data
        handler_parent['handler'] = handler_data

        job_data
      end

      private

      def extract_job_data
        if job.respond_to?(:as_json)
          job.as_json
        else
          Hash[job.to_hash.map { |k, v| [k.to_s, v] }]
        end
      end

      def handler_data
        payload_object = job.payload_object

        return object_data(payload_object.object) if payload_object.respond_to?(:object)

        # ActiveJob jobs enqueued through the delayed_job adapter
        if payload_object.respond_to?(:job_data)
          return active_job_data(payload_object.job_data)
        end

        payload_data(payload_object)
      rescue StandardError
        {}
      end

      def active_job_data(job_data)
        return scrub(job_data) unless log_arguments_disabled?(job_data['job_class'])

        scrubbed_arguments = Array(job_data['arguments']).map do |argument|
          Rollbar::Scrubbers.scrub_value(argument)
        end

        scrub(job_data.merge('arguments' => scrubbed_arguments))
      end

      def log_arguments_disabled?(job_class_name)
        job_class = Object.const_get(job_class_name.to_s)

        job_class.respond_to?(:log_arguments?) && !job_class.log_arguments?
      rescue NameError
        false
      end

      # Custom job objects would otherwise be sent as their #to_s
      # representation, e.g. "#<MyCustomJob:0x000056...>".
      def payload_data(payload_object)
        case payload_object
        when ::Hash, Array, String, Numeric, Symbol, true, false, nil
          payload_object
        else
          {
            'class' => payload_object.class.name,
            'attributes' => scrub(payload_attributes(payload_object))
          }
        end
      rescue SystemStackError
        # as_json recurses forever on objects with circular references
        { 'class' => payload_object.class.name }
      end

      def payload_attributes(payload_object)
        return payload_object.as_json if payload_object.respond_to?(:as_json)
        return payload_object.to_h if payload_object.is_a?(Struct)

        Hash[payload_object.instance_variables.map do |name|
          [name.to_s.delete('@'), payload_object.instance_variable_get(name)]
        end]
      end

      def scrub(params)
        Rollbar::Scrubbers::Params.call(
          :params => params,
          :config => Rollbar.configuration.scrub_fields,
          :whitelist => Rollbar.configuration.scrub_whitelist
        )
      end

      def object_data(object)
        {
          :method_name => job.payload_object.method_name,
          :args => job.payload_object.args,
          :object => object.is_a?(Class) ? object.name : object.to_s
        }
      rescue StandardError
        {}
      end
    end
  end
end
