Rollbar.plugins.define('thread') do
  module Rollbar
    module ThreadPlugin
      def initialize(*args)
        self[:_rollbar_notifier] ||= Rollbar.notifier.scope
        super
      end
    end
  end

  execute do
    Thread.send(:prepend, Rollbar::ThreadPlugin) # rubocop:disable Lint/SendWithMixinArgument
  end
end
