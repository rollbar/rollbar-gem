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
        body = new_payload['data'].delete(:body)
        trace_key = body[:trace_chain] ? :trace_chain : :trace

        if trace_key == :trace_chain
          body[:trace_chain] = body[trace_key].map do |trace_data|
            truncate_trace_data(trace_data)
          end
        elsif trace_key == :trace
          body[:trace] = truncate_trace_data(body[trace_key])
        end
      end

      def truncate_trace_data(trace_data)
        trace_data[:exception].delete(:description)
        trace_data[:exception][:message] = trace_data[:exception][:message][0, 255]
        trace_data[:frames] = select_frames(trace_data[:frames], 1)

        trace_data
      end
    end
  end
end
