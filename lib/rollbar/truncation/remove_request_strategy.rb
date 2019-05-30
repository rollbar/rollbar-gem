require 'rollbar/util'

module Rollbar
  module Truncation
    class RemoveRequestStrategy
      include ::Rollbar::Truncation::Mixin

      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        data = payload['data']

        data.delete('request') if data['request']

        dump(payload)
      end
    end
  end
end
