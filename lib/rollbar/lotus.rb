require 'rollbar'

module Rollbar
  module Lotus
    def self.initialize
      env = ::Lotus::Environment.new

      Rollbar.preconfigure do |config|
        config.logger = ::Lotus::Logger.new
        config.environment = env.environment
        config.root = env.root
        config.framework = "Lotus: #{::Lotus::VERSION}"
      end
    end
  end
end

Rollbar::Lotus.initialize
