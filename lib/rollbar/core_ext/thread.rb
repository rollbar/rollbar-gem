class Thread
  def initialize_with_rollbar(*args, &block)
    self[:_rollbar_notifier] ||= Rollbar.notifier.scope
    initialize_without_rollbar(*args, &block)
  end

  alias_method :initialize_without_rollbar, :initialize
  alias_method :initialize, :initialize_with_rollbar
end
