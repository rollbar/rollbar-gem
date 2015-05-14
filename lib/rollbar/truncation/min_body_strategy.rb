require 'rollbar/truncation/mixin'

module Rollbar
  module Truncation
    class MinBodyStrategy
      include ::Rollbar::Truncation::Mixin

      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        new_payload = payload.clone
        body = new_payload['data']['body']

        if body['trace_chain']
          body['trace_chain'] = body['trace_chain'].map do |trace_data|
            truncate_trace_data(trace_data)
          end
        elsif body['trace']
          body['trace'] = truncate_trace_data(body['trace'])
        end


        dump(new_payload)
      end

      def truncate_trace_data(trace_data)
        trace_data['exception'].delete('description')
        trace_data['exception']['message'] = trace_data['exception']['message'][0, 255]
        trace_data['frames'] = select_frames(trace_data['frames'], 1)

        trace_data
      end
    end
  end
end
