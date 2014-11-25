require 'rollbar/util'
require 'rollbar/truncation/mixin'
require 'rollbar/truncation/raw_strategy'
require 'rollbar/truncation/frames_strategy'
require 'rollbar/truncation/strings_strategy'
require 'rollbar/truncation/min_body_strategy'

module Rollbar
  module Truncation
    extend ::Rollbar::Truncation::Mixin

    MAX_PAYLOAD_SIZE = 128 * 1024 # 128kb
    STRATEGIES = [RawStrategy,
                  FramesStrategy,
                  StringsStrategy,
                  MinBodyStrategy
                 ]

    def self.truncate(payload)
      STRATEGIES.each do |strategy|
        result = strategy.call(payload)
        return result unless truncate?(result)
      end

      nil
    end
  end
end
