require 'rollbar/util'

module Rollbar
  module Truncation
    class RemoveAnyKeyStrategy
      include ::Rollbar::Truncation::Mixin

      attr_accessor :payload, :data, :sizes, :extracted_title

      def self.call(payload)
        new(payload).call
      end

      def initialize(payload)
        @payload = payload
        @data = payload['data']
        @extracted_title = extract_title(data['body']) if data['body']
      end

      def call
        remove_unknown_root_keys

        json_payload = remove_oversized_data_keys

        return json_payload if json_payload

        dump(payload)
      end

      def remove_unknown_root_keys
        payload.keys.reject { |key| root_keys.include?(key) }.each do |key|
          truncation_key['root'] ||= {}
          size = dump(payload.delete(key)).bytesize
          truncation_key['root'][key] = "unknown root key removed, size: #{size} bytes"
        end
      end

      def remove_oversized_data_keys
        data_keys.keys.sort { |a, b| data_keys[b] <=> data_keys[a] }.each do |key|
          json_payload = remove_key_and_return_payload(key)

          return json_payload unless truncate?(json_payload)
        end

        false
      end

      def remove_key_and_return_payload(key)
        size = data_keys[key]

        data.delete(key)

        replace_message_body if key == 'body'

        truncation_key[key] = "key removed, size: #{size} bytes"

        dump(payload)
      end

      def replace_message_body
        data['body'] = message_key
        data['title'] ||= extracted_title if extracted_title
      end

      def truncation_key
        @truncation_key ||=
          # initialize the diagnostic key for truncation
          (data['notifier']['diagnostic'] ||= {}) &&
          (data['notifier']['diagnostic']['truncation'] ||= {})
      end

      def root_keys
        # Valid keys in root of payload
        %w[access_token data]
      end

      def skip_keys
        # Don't try to truncate these data keys
        %w[notifier uuid title platform language framework level]
      end

      def message_key
        # use this message if data.body gets removed
        {
          'message' => {
            'body' => 'Payload keys removed due to oversized payload. See diagnostic key'
          }
        }
      end

      def extract_title(body)
        return body['message']['body'] if body['message'] && body['message']['body']
        return extract_title_from_trace(body['trace']) if body['trace']

        return unless body['trace_chain'] && body['trace_chain'][0]

        extract_title_from_trace(body['trace_chain'][0])
      end

      def extract_title_from_trace(trace)
        exception = trace['exception']

        "#{exception['class']}: #{exception['message']}"
      end

      def data_keys
        @data_keys ||= {}.tap do |hash|
          data.keys.reject { |key| skip_keys.include?(key) }.each do |key|
            set_key_size(key, hash)
          end
        end
      end

      def set_key_size(key, hash)
        size = dump(data[key]).bytesize
        hash[key] = size
      rescue ::JSON::GeneratorError
        hash[key] = 0 # don't try to truncate non JSON object

        # Log it
        truncation_key['non_json_keys'] ||= {}
        truncation_key['non_json_keys'][key] = data[key].class
      end
    end
  end
end
