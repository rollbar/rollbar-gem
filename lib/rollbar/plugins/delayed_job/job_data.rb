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

        return payload_object unless payload_object.respond_to?(:object)

        object_data(payload_object.object)
      rescue StandardError
        {}
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
