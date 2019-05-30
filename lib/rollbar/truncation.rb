require 'rollbar/util'
require 'rollbar/truncation/mixin'
require 'rollbar/truncation/raw_strategy'
require 'rollbar/truncation/frames_strategy'
require 'rollbar/truncation/strings_strategy'
require 'rollbar/truncation/min_body_strategy'
require 'rollbar/truncation/remove_request_strategy'
require 'rollbar/truncation/remove_extra_strategy'

module Rollbar
  module Truncation
    extend ::Rollbar::Truncation::Mixin

    MAX_PAYLOAD_SIZE = 512 * 1024 # 512kb
    STRATEGIES = [RawStrategy,
                  FramesStrategy,
                  StringsStrategy,
                  MinBodyStrategy,
                  RemoveRequestStrategy,
                  RemoveExtraStrategy].freeze

    def self.truncate(payload, attempts = [])
      result = nil

      STRATEGIES.each do |strategy|
        result = strategy.call(payload)
        attempts << result.bytesize
        break unless truncate?(result)
      end

      result
    end
  end
end
