require 'rollbar/truncation/mixin'

module Rollbar
  module Truncation
    class FramesStrategy
      include ::Rollbar::Truncation::Mixin

      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        new_payload = payload.clone
        body = new_payload['data'][:body]
        trace_key = body[:trace_chain] ? :trace_chain : :trace

        if trace_key == :trace_chain
          truncate_trace_chain(body)
        elsif trace_key == :trace
          truncate_trace(body)
        end

        dump(new_payload)
      end

      def truncate_trace(body)
        trace_data = body[:trace]
        frames = trace_data[:frames]
        trace_data[:frames] = select_frames(frames)

        body[:trace][:frames] = select_frames(body[:trace][:frames])
      end

      def truncate_trace_chain(body)
        chain = body[:trace_chain]

        body[:trace_chain] = chain.map do |trace_data|
          frames = trace_data[:frames]
          trace_data[:frames] = select_frames(frames)
          trace_data
        end
      end
    end
  end
end
