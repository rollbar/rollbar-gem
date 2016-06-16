Rollbar.plugins.define('thread') do
  execute do
    Thread.class_eval do
      def initialize_with_rollbar(*args, &block)
        self[:_rollbar_notifier] ||= Rollbar.notifier.scope
        initialize_without_rollbar(*args, &block)
      end

      alias_method :initialize_without_rollbar, :initialize
      alias_method :initialize, :initialize_with_rollbar
    end
  end
end
