class Thread
  class << self
    def new_with_rollbar(*args, &block)
      th = old_new(*args, &block)
      th[:_rollbar_notifier] ||= Rollbar.notifier.scope
      th
    end

    alias_method :old_new, :new
    alias_method :new, :new_with_rollbar
  end
end
