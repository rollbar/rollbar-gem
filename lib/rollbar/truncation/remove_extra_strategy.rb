require 'rollbar/util'

module Rollbar
  module Truncation
    class RemoveExtraStrategy
      include ::Rollbar::Truncation::Mixin

      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        body = payload['data']['body']

        delete_message_extra(body)
        delete_trace_chain_extra(body)
        delete_trace_extra(body)

        dump(payload)
      end

      def delete_message_extra(body)
        body['message'].delete('extra') if body['message'] && body['message']['extra']
      end

      def delete_trace_chain_extra(body)
        if body['trace_chain'] && body['trace_chain'][0]['extra']
          body['trace_chain'][0].delete('extra')
        end
      end

      def delete_trace_extra(body)
        body['trace'].delete('extra') if body['trace'] && body['trace']['extra']
      end
    end
  end
end
