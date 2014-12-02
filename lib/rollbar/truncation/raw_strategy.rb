require 'rollbar/truncation/mixin'

module Rollbar
  module Truncation
    class RawStrategy
      include ::Rollbar::Truncation::Mixin

      def self.call(payload)
        new.call(payload)
      end

      def call(payload)
        dump(payload)
      end
    end
  end
end
