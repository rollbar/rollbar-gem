require 'rollbar/util'
require 'rollbar/truncation/mixin'
require 'rollbar/truncation/raw_strategy'
require 'rollbar/truncation/frames_strategy'
require 'rollbar/truncation/strings_strategy'
require 'rollbar/truncation/min_body_strategy'

module Rollbar
  module Truncation
    extend ::Rollbar::Truncation::Mixin

    MAX_PAYLOAD_SIZE = 512 * 1024 # 512kb
    STRATEGIES = [RawStrategy,
                  FramesStrategy,
                  StringsStrategy,
                  MinBodyStrategy].freeze

    def self.truncate(payload)
      result = nil

      STRATEGIES.each do |strategy|
        result = strategy.call(payload)
        break unless truncate?(result)
      end

      result
    end
  end
end
